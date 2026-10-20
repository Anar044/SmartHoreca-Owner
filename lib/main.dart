import 'package:flutter/material.dart';
import 'core/owner_backend.dart';
import 'core/owner_push_service.dart';
import 'core/owner_state.dart';
import 'core/owner_theme.dart';
import 'screens/auth_screens.dart';
import 'screens/owner_shell.dart';
import 'screens/owner_splash.dart';
import 'screens/owner_live_reports.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OwnerBackend.initialize();
  // Firebase remains optional until the Android project is configured.
  await OwnerPushService.initialize();
  runApp(const SmartHorecaOwnerApp());
}

class SmartHorecaOwnerApp extends StatefulWidget {
  const SmartHorecaOwnerApp({super.key});

  @override
  State<SmartHorecaOwnerApp> createState() => _SmartHorecaOwnerAppState();
}

class _SmartHorecaOwnerAppState extends State<SmartHorecaOwnerApp> {
  final OwnerState owner = OwnerState();
  final GlobalKey<ScaffoldMessengerState> messenger =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  bool _ready = false;
  bool _openingPushOrder = false;

  void _tryOpenPushOrder() {
    if (!mounted || !_ready || _openingPushOrder ||
        owner.stage != OwnerStage.shell || !owner.live) {
      return;
    }
    final target = OwnerPushService.pendingOrder;
    if (target == null) return;
    _openingPushOrder = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { _openingPushOrder = false; return; }
      if (!OwnerBackend.hasSession || owner.stage != OwnerStage.shell ||
          owner.workspaceId == null) {
        _openingPushOrder = false;
        return; // Keep the pending tap until the owner logs in.
      }
      final names = owner.restaurantIdsByName.entries
          .where((entry) => entry.value == target.departmentId).toList();
      if (names.isEmpty) {
        OwnerPushService.clearPendingOrder();
        _openingPushOrder = false;
        messenger.currentState?.showSnackBar(const SnackBar(content:
          Text('У вас нет доступа к ресторану этого уведомления.')));
        return;
      }
      // A restaurant can be authorized but unchecked in the owner's list.
      // Select it using the existing authenticated restaurant selector.
      if (!owner.selectedRestaurantIds.contains(target.departmentId)) {
        owner.selectRestaurant(names.first.key, true);
      }
      final nav = navigator.currentState;
      if (nav == null) { _openingPushOrder = false; return; }
      OwnerPushService.clearPendingOrder();
      nav.push<void>(MaterialPageRoute<void>(
        builder: (_) => OwnerLivePosOrderScreen(
          order: <String,dynamic>{'number': target.orderNum},
          pluginId: target.pluginId,
          departmentId: target.departmentId,
          restaurant: names.first.key,
          registerName: 'Касса',
        ),
      )).whenComplete(() {
        _openingPushOrder = false;
        _tryOpenPushOrder();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    owner.addListener(_tryOpenPushOrder);
    OwnerPushService.onOrderTap = (_) => _tryOpenPushOrder();
    OwnerPushService.onForegroundAlert = (title,body,target) {
      final scaffold=messenger.currentState;
      if(scaffold==null)return;
      scaffold.hideCurrentSnackBar();
      scaffold.showSnackBar(SnackBar(
        duration:const Duration(seconds:7),
        content:Text('$title\n$body'),
        action:SnackBarAction(
          label:target == null ? 'Закрыть' : 'Открыть',
          onPressed:() {
            if(target == null) {
              scaffold.hideCurrentSnackBar();
            } else {
              OwnerPushService.openOrder(target);
            }
          }),
      ));
    };
    Future<void>.microtask(() async {
      try {
        await owner.loadPreferences();
        await owner.restoreSession();
      } finally {
        if(mounted) {
          setState(() => _ready = true);
          _tryOpenPushOrder();
        }
      }
    });
  }

  @override
  void dispose() {
    OwnerPushService.onForegroundAlert=null;
    OwnerPushService.onOrderTap=null;
    owner.removeListener(_tryOpenPushOrder);
    owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: owner,
      builder: (context, _) => OwnerScope(
        state: owner,
        child: MaterialApp(
          scaffoldMessengerKey:messenger,
          navigatorKey:navigator,
          title: 'Smart Horeca Owner',
          debugShowCheckedModeBanner: false,
          theme: OwnerPalette.light,
          darkTheme: OwnerPalette.dark,
          themeMode: owner.themeMode,
          home: !_ready ? const OwnerSplashScreen() : switch (owner.stage) {
            OwnerStage.signIn => const OwnerSignInScreen(),
            OwnerStage.workspaces => const OwnerWorkspaceSelectScreen(),
            OwnerStage.restaurants => const OwnerRestaurantSelectScreen(),
            OwnerStage.shell => const OwnerShell(),
          },
        ),
      ),
    );
  }
}
