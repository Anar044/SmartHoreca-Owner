import 'package:flutter/material.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../core/owner_l10n.dart';
import 'home_screen.dart';
import 'cash_screen.dart';
import 'reports_screen.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';
import '../ui/owner_brand.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  final Set<int> _activatedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    // Build each page just once when first opened, and keep it mounted in
    // IndexedStack. Tab changes must NEVER trigger a data reload.
    _activatedTabs.add(state.tabIndex);
    const pages = [
      OwnerHomeScreen(),
      OwnerCashScreen(),
      OwnerReportsScreen(),
      OwnerAiScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const OwnerBrandMark(size: 39),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Smart Horeca Owner', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
              Text(OwnerL10n.tr(state.language, 'Ваш бизнес под контролем'),
                style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.normal)),
            ],
          )),
        ]),
        actions: [
          IconButton(
            tooltip: OwnerL10n.tr(state.language, 'Уведомления'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => const OwnerNotificationsScreen(),
            )),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            tooltip: OwnerL10n.tr(state.language, 'Профиль'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => const OwnerProfileScreen(),
            )),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: state.tabIndex, children: [
        for (var i = 0; i < pages.length; i++)
          if (_activatedTabs.contains(i))
            pages[i]
          else
            const SizedBox.shrink(),
      ]),
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
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: OwnerL10n.tr(state.language, 'Главная')),
          BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet_outlined), activeIcon: const Icon(Icons.account_balance_wallet), label: OwnerL10n.tr(state.language, 'Кассы')),
          BottomNavigationBarItem(icon: const Icon(Icons.bar_chart_outlined), activeIcon: const Icon(Icons.bar_chart), label: OwnerL10n.tr(state.language, 'Отчёты')),
          const BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
