import 'package:flutter/material.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import 'home_screen.dart';
import 'cash_screen.dart';
import 'reports_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';

class OwnerShell extends StatelessWidget {
  const OwnerShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    const pages = [
      OwnerHomeScreen(),
      OwnerCashScreen(),
      OwnerReportsScreen(),
      OwnerAiScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Horeca Owner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Ваш бизнес под контролем', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => const OwnerNotificationsScreen(),
            )),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            tooltip: 'Профиль',
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => const OwnerProfileScreen(),
            )),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: state.tabIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: OwnerPalette.surface(context),
        selectedItemColor: OwnerPalette.accent(context),
        unselectedItemColor: OwnerPalette.muted(context),
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: state.tabIndex,
        onTap: state.setTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Кассы'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Отчёты'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
