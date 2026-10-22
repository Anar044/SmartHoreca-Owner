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


/// Verified routing metadata only; order details are always fetched through
/// read-only workspace-scoped APIs after login.
class OwnerPushOrderTarget {
  final String departmentId;
  final String pluginId;
  final String orderNum;
  final String kind;
  const OwnerPushOrderTarget({
    required this.departmentId,
    required this.pluginId,
    required this.orderNum,
    required this.kind,
  });
  static OwnerPushOrderTarget? fromData(Map<String, dynamic> data) {
    final departmentId = (data['departmentId'] ?? '').toString().trim();
    final pluginId = (data['pluginId'] ?? '').toString().trim();
    final orderNum = (data['orderNum'] ?? '').toString().trim();
    final kind = (data['kind'] ?? '').toString().trim();
    const validKinds = <String>{
      'DISCOUNT_APPLIED', 'DISCOUNT_REMOVED', 'PRECHECK_CANCELLED',
      'ITEM_REMOVED', 'RECEIPT_STORNO'
    };
    final id = RegExp(r'^[0-9a-fA-F-]{36}$');
    if (!id.hasMatch(departmentId) || !id.hasMatch(pluginId) ||
        orderNum.isEmpty || orderNum.length > 120 ||
        !validKinds.contains(kind)) {
      return null;
    }
    return OwnerPushOrderTarget(
      departmentId: departmentId, pluginId: pluginId,
      orderNum: orderNum, kind: kind,
    );
  }
}

class OwnerPushService {
  OwnerPushService._();
  static const _apiKey=String.fromEnvironment('SH_FIREBASE_ANDROID_API_KEY');
  static const _appId=String.fromEnvironment('SH_FIREBASE_ANDROID_APP_ID');
  static const _senderId=String.fromEnvironment('SH_FIREBASE_SENDER_ID');
  static const _projectId=String.fromEnvironment('SH_FIREBASE_PROJECT_ID');
  // iOS Firebase is a separate Firebase app, bound to the final Apple bundle
  // ID. Android values must NEVER be reused as the iOS appId/API key.
  static const _iosApiKey=String.fromEnvironment('SH_FIREBASE_IOS_API_KEY');
  static const _iosAppId=String.fromEnvironment('SH_FIREBASE_IOS_APP_ID');
  static const _iosBundleId=String.fromEnvironment('SH_FIREBASE_IOS_BUNDLE_ID');

  static bool get configured =>
    _senderId.isNotEmpty && _projectId.isNotEmpty &&
    ((Platform.isAndroid && _apiKey.isNotEmpty && _appId.isNotEmpty) ||
     (Platform.isIOS && _iosApiKey.isNotEmpty &&
      _iosAppId.isNotEmpty && _iosBundleId.isNotEmpty));

  static bool _initialized=false;
  static bool _enabled=false;
  static String? _workspace;
  static Set<String> _departments={};
  static void Function(String,String,OwnerPushOrderTarget?)? onForegroundAlert;
  static void Function(OwnerPushOrderTarget)? onOrderTap;
  static OwnerPushOrderTarget? _pendingOrder;
  static OwnerPushOrderTarget? get pendingOrder => _pendingOrder;
  static void clearPendingOrder() => _pendingOrder = null;
  static void openOrder(OwnerPushOrderTarget target) {
    _pendingOrder = target;
    onOrderTap?.call(target);
  }
  static void _openMessage(RemoteMessage message) {
    final target = OwnerPushOrderTarget.fromData(message.data);
    if (target != null) openOrder(target);
  }

  static const kinds=<String>[
    'DISCOUNT_APPLIED','DISCOUNT_REMOVED','PRECHECK_CANCELLED',
    'ITEM_REMOVED','RECEIPT_STORNO',
  ];

  static Future<void> initialize() async {
    if(!configured || _initialized)return;
    try{
      final options = Platform.isIOS
        ? const FirebaseOptions(
            apiKey:_iosApiKey,appId:_iosAppId,
            messagingSenderId:_senderId,projectId:_projectId,
            iosBundleId:_iosBundleId,
          )
        : const FirebaseOptions(
            apiKey:_apiKey,appId:_appId,
            messagingSenderId:_senderId,projectId:_projectId,
          );
      await Firebase.initializeApp(options:options);
      FirebaseMessaging.onBackgroundMessage(ownerPushBackgroundHandler);
      FirebaseMessaging.onMessage.listen((message){
        final n=message.notification;
        final title=n?.title ?? 'Smart Horeca Owner';
        final body=n?.body ?? 'Новое событие кассы';
        onForegroundAlert?.call(title,body,
          OwnerPushOrderTarget.fromData(message.data));
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
      final launchMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (launchMessage != null) _openMessage(launchMessage);
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

  // On iPhone FCM cannot issue a usable registration token until APNs has
  // registered the device. iOS may need a short moment after permission.
  static Future<String?> _readyFcmToken() async {
    if (Platform.isIOS) {
      String? apns;
      for (var attempt=0;attempt<8;attempt++) {
        apns=await FirebaseMessaging.instance.getAPNSToken();
        if (apns!=null && apns.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds:500));
      }
      if(apns==null||apns.isEmpty) {
        throw const OwnerApiException('APNS_TOKEN_UNAVAILABLE',
          'iPhone не зарегистрирован в APNs. Проверьте Push Notifications '
          'в Apple Developer, APNs Key в Firebase и разрешение уведомлений.',
          503);
      }
    }
    return FirebaseMessaging.instance.getToken();
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

  static String _kindsKey(String workspace) {
    final userId=OwnerBackend.hasSession
      ?OwnerBackend.client.auth.currentUser?.id??'' : '';
    return 'sh_owner_push_kinds_${userId}_$workspace';
  }

  static Future<Set<String>> selectedKinds(String workspace) async {
    if (!OwnerBackend.hasSession) return kinds.toSet();
    final saved=await SharedPreferencesAsync().getStringList(
      _kindsKey(workspace));
    if (saved == null) return kinds.toSet();
    return saved.where(kinds.contains).toSet();
  }

  static Future<void> _registerToken(
      String token,String workspace,Iterable<String> restaurants,
      {Set<String>? onlyKinds}) async {
    final chosen=onlyKinds??await selectedKinds(workspace);
    if (chosen.isEmpty) {
      throw const OwnerApiException('NO_ALERT_TYPES',
        'Отметьте хотя бы одно событие или отключите Push целиком.',400);
    }
    await OwnerBackend.postJson('/api/mobile/v1/push-subscriptions',
      workspaceId:workspace,
      departmentIds:restaurants,
      payload:{
        'action':'register','token':token,
        'kinds':kinds.where(chosen.contains).toList()
      },
    );
  }

  static Future<void> updateKinds(String workspace,
      Iterable<String> restaurants,Set<String> next) async {
    if (next.any((kind)=>!kinds.contains(kind))) {
      throw const OwnerApiException('UNKNOWN_ALERT_TYPE',
        'Неизвестный тип уведомления.',400);
    }
    if (next.isEmpty) {
      // Unchecking the last kind automatically disables push and revokes
      // the device token. Empty preferences cannot leave an active server
      // subscription unintentionally delivering notifications.
      if (await isEnabled()) await disable();
      await SharedPreferencesAsync().setStringList(_kindsKey(workspace),[]);
      return;
    }
    // Server must accept the new selection before the UI considers it saved.
    if (await isEnabled()) {
      await initialize();
      if (!_initialized) {
        throw const OwnerApiException('FIREBASE_UNAVAILABLE',
          'Firebase сейчас недоступен. Попробуйте позже.',503);
      }
      final token=await _readyFcmToken();
      if (token == null || token.isEmpty) {
        throw const OwnerApiException('FCM_TOKEN_UNAVAILABLE',
          'Не удалось получить токен для обновления подписки.',503);
      }
      await _registerToken(token,workspace,restaurants,onlyKinds:next);
    }
    await SharedPreferencesAsync().setStringList(
      _kindsKey(workspace),kinds.where(next.contains).toList());
  }

  // Read-only server-side check; never expose or log the FCM device token.
  // Local push preferences alone do not prove an active server subscription.
  static Future<String> checkConnection(
      String workspace, Iterable<String> restaurants) async {
    if (!configured) {
      return Platform.isIOS
        ?'Для iPhone не настроена Firebase iOS App. Проверьте GitHub '
          'SH_FIREBASE_IOS_API_KEY, SH_FIREBASE_IOS_APP_ID и Apple Bundle ID.'
        :'Firebase не настроен для этого устройства.';
    }
    await initialize();
    if (!_initialized) {
      return 'Не удалось инициализировать Firebase на телефоне.';
    }
    if (!OwnerBackend.hasSession) {
      return 'Сначала войдите в аккаунт Smart Horeca.';
    }
    final ids = restaurants.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) {
      return 'Сначала выберите хотя бы один ресторан.';
    }
    String? token;
    try {
      token=await _readyFcmToken();
    } on OwnerApiException catch(e) {
      return e.message;
    }
    if (token == null || token.isEmpty) {
      return 'Firebase не выдал токен этому телефону.';
    }
    final result = await OwnerBackend.postJson(
      '/api/mobile/v1/push-subscriptions',
      workspaceId: workspace,
      departmentIds: ids,
      payload: {'action': 'status', 'token': token},
    );
    final serverConfigured = result['configured'] == true;
    final serverEnabled = result['enabled'] == true;
    final localEnabled = await isEnabled();
    if (!serverConfigured) {
      return 'Сервер не настроен для отправки Firebase push. '
          'Проверьте FCM_SERVICE_ACCOUNT_JSON в том окружении Cloudflare, '
          'к которому подключено приложение.';
    }
    if (!serverEnabled) {
      return localEnabled
          ? 'Подписка есть в телефоне, но не зарегистрирована на сервере. '
              'Выключите Push и включите его снова.'
          : 'Подписка телефона не активна. Включите Push выше.';
    }
    final kinds = (result['kinds'] as List? ?? []).whereType<String>().toSet();
    if (!kinds.contains('DISCOUNT_APPLIED')) {
      return 'Подписка на сервере активна, но событие «Применена скидка» '
          'выключено. Поставьте галочку напротив этого события.';
    }
    return 'FCM-секрет присутствует на сервере, телефон зарегистрирован, '
        'уведомление о скидке разрешено. '
        'Доставка пока не подтверждена: проверьте, что события кассы '
        'попадают на этот же сервер, и журнал отправки FCM.';
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
    final token=await _readyFcmToken();
    if(token!=null){
      await _registerToken(token,workspace,_departments);
    }
  }

  static Future<void> enable(
      String workspace,Iterable<String> restaurants) async {
    if(!configured){
      throw const OwnerApiException(
        'FIREBASE_NOT_CONFIGURED',
        'Firebase Cloud Messaging не настроен для этого устройства.',503);
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
        'Разрешите уведомления SH Owner в настройках телефона.',403);
    }
    final token=await _readyFcmToken();
    if(token==null||token.isEmpty){
      throw const OwnerApiException('FCM_TOKEN_UNAVAILABLE',
        'Не удалось получить токен уведомлений. Повторите позднее.',503);
    }
    final chosen=await selectedKinds(workspace);
    await _registerToken(token,workspace,restaurants,onlyKinds:chosen);
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
    final token=await _readyFcmToken();
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
    clearPendingOrder();
    // Keep this account's opt-in choice across logins, but revoke this
    // device's current FCM token immediately on sign-out.
    _enabled=false;
    try{await _unregisterAndDelete();}catch(_){}
    _workspace=null;_departments={};
  }
}
