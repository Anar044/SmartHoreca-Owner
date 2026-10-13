import 'package:flutter/material.dart';
import 'core/owner_state.dart';
import 'core/owner_theme.dart';
import 'screens/auth_screens.dart';
import 'screens/owner_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartHorecaOwnerApp());
}

class SmartHorecaOwnerApp extends StatefulWidget {
  const SmartHorecaOwnerApp({super.key});

  @override
  State<SmartHorecaOwnerApp> createState() => _SmartHorecaOwnerAppState();
}

class _SmartHorecaOwnerAppState extends State<SmartHorecaOwnerApp> {
  final OwnerState owner = OwnerState();

  @override
  void dispose() {
    owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: owner,
      builder: (context, _) => OwnerScope(
        state: owner,
        // Scope is above the Navigator so pushed routes keep the same settings
        // and selected restaurants, including theme switches from Profile.
        child: MaterialApp(
          title: 'Smart Horeca Owner',
          debugShowCheckedModeBanner: false,
          theme: OwnerPalette.light,
          darkTheme: OwnerPalette.dark,
          themeMode: owner.themeMode,
          home: switch (owner.stage) {
            OwnerStage.signIn => const OwnerSignInScreen(),
            OwnerStage.restaurants => const OwnerRestaurantSelectScreen(),
            OwnerStage.shell => const OwnerShell(),
          },
        ),
      ),
    );
  }
}
