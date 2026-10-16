import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'owner_backend.dart';

@pragma('vm:entry-point')
Future<void> ownerPushBackgroundHandler(RemoteMessage message) async {
  // The Android system displays FCM "notification" payloads when backgrounded.
  // Never log token, message body, or event details here.
}

class OwnerPushService {
  OwnerPushService._();
  static const _apiKey=String.fromEnvironment('SH_FIREBASE_ANDROID_API_KEY');
  static const _appId=String.fromEnvironment('SH_FIREBASE_ANDROID_APP_ID');
  static const _senderId=String.fromEnvironment('SH_FIREBASE_SENDER_ID');
  static const _projectId=String.fromEnvironment('SH_FIREBASE_PROJECT_ID');

  static bool get configured => Platform.isAndroid &&
    _apiKey.isNotEmpty && _appId.isNotEmpty &&
    _senderId.isNotEmpty && _projectId.isNotEmpty;

  static bool _initialized=false;
  static bool _enabled=false;
  static String? _workspace;
  static Set<String> _departments={};
  static void Function(String,String)? onForegroundAlert;

  static const kinds=<String>[
    'DISCOUNT_APPLIED','DISCOUNT_REMOVED','PRECHECK_CANCELLED',
    'ITEM_REMOVED','RECEIPT_STORNO',
  ];

  static Future<void> initialize() async {
    if(!configured || _initialized)return;
    try{
      await Firebase.initializeApp(options:const FirebaseOptions(
        apiKey:_apiKey,appId:_appId,
        messagingSenderId:_senderId,projectId:_projectId,
      ));
      FirebaseMessaging.onBackgroundMessage(ownerPushBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message){
        final n=message.notification;
        final title=n?.title ?? 'Smart Horeca Owner';
        final body=n?.body ?? 'Новое событие кассы';
        onForegroundAlert?.call(title,body);
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token){
        if(_enabled && _workspace!=null && _departments.isNotEmpty){
          unawaited(_registerToken(token,_workspace!,_departments));
        }
      });
      _initialized=true;
    }catch(_){
      // Firebase credentials may not yet be installed in a pilot build.
      _initialized=false;
    }
  }

  static String get _optInKey {
    final userId=OwnerBackend.hasSession
        ?OwnerBackend.client.auth.currentUser?.id??''
        :'';
    return 'sh_owner_push_opt_in_$userId';
  }
  static Future<bool> isEnabled() async {
    if(!OwnerBackend.hasSession)return false;
    final prefs=SharedPreferencesAsync();
    return await prefs.getBool(_optInKey)??false;
  }

  static Future<void> _registerToken(
      String token,String workspace,Iterable<String> restaurants) async {
    await OwnerBackend.postJson('/api/mobile/v1/push-subscriptions',
      workspaceId:workspace,
      departmentIds:restaurants,
      payload:{'action':'register','token':token,'kinds':kinds},
    );
  }

  static Future<void> syncScope(
      String workspace,Iterable<String> restaurants) async {
    _workspace=workspace;
    _departments=restaurants.where((s)=>s.isNotEmpty).toSet();
    if(!configured)return;
    await initialize();
    if(!_initialized)return;
    _enabled=await isEnabled();
    if(!_enabled||_departments.isEmpty||!OwnerBackend.hasSession)return;
    final token=await FirebaseMessaging.instance.getToken();
    if(token!=null){
      await _registerToken(token,workspace,_departments);
    }
  }

  static Future<void> enable(
      String workspace,Iterable<String> restaurants) async {
    if(!configured){
      throw const OwnerApiException(
        'FIREBASE_NOT_CONFIGURED',
        'Firebase Cloud Messaging ещё не подключён к Android-сборке.',503);
    }
    await initialize();
    if(!_initialized){
      throw const OwnerApiException(
        'FIREBASE_INIT_FAILED','Не удалось запустить Firebase.',503);
    }
    final permission=await FirebaseMessaging.instance.requestPermission(
      alert:true,badge:true,sound:true,
    );
    if(permission.authorizationStatus!=AuthorizationStatus.authorized &&
       permission.authorizationStatus!=AuthorizationStatus.provisional){
      throw const OwnerApiException('PUSH_PERMISSION_DENIED',
        'Разрешите уведомления Smart Horeca в настройках Android.',403);
    }
    final token=await FirebaseMessaging.instance.getToken();
    if(token==null||token.isEmpty){
      throw const OwnerApiException('FCM_TOKEN_UNAVAILABLE',
        'Не удалось получить токен уведомлений. Повторите позднее.',503);
    }
    await _registerToken(token,workspace,restaurants);
    _workspace=workspace;
    _departments=restaurants.toSet();
    _enabled=true;
    await SharedPreferencesAsync().setBool(_optInKey,true);
  }

  static Future<void> disable() async {
    _enabled=false;
    if(OwnerBackend.hasSession){
      await SharedPreferencesAsync().setBool(_optInKey,false);
    }
    await _unregisterAndDelete();
  }

  static Future<void> _unregisterAndDelete() async {
    if(!_initialized){
      return;
    }
    final workspace=_workspace;
    final token=await FirebaseMessaging.instance.getToken();
    if(workspace!=null&&token!=null&&OwnerBackend.hasSession){
      try{
        await OwnerBackend.postJson('/api/mobile/v1/push-subscriptions',
          workspaceId:workspace,departmentIds:_departments,
          payload:{'action':'unregister','token':token},
        );
      }catch(_){
        // Deleting the FCM token below invalidates delivery on sign-out.
      }
    }
    await FirebaseMessaging.instance.deleteToken();
  }

  static Future<void> onSignOut() async {
    // Keep this account's opt-in choice across logins, but revoke this
    // device's current FCM token immediately on sign-out.
    _enabled=false;
    try{await _unregisterAndDelete();}catch(_){}
    _workspace=null;_departments={};
  }
}
