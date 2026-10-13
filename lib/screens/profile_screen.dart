import 'package:flutter/material.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';
import '../ui/owner_components.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = OwnerScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: OwnerScreenFrame(children: [
        OwnerCard(child: Row(children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: OwnerPalette.accent(context),
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Владелец ресторана', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Настройки владельца', style: TextStyle(fontSize: 11)),
          ])),
        ])),
        const SizedBox(height: 12),
        OwnerCard(
          onTap: () {
            Navigator.pop(context);
            state.showRestaurants();
          },
          child: ListTile(contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.store_outlined),
            title: const Text('Мои рестораны'),
            trailing: Text('${state.selectedRestaurants.length}'),
          ),
        ),
        const SizedBox(height: 12),
        const OwnerHeading('Тема оформления'),
        const SizedBox(height: 9),
        OwnerCard(child: RadioGroup<ThemeMode>(
          groupValue: state.themeMode,
          onChanged: (value) { if (value != null) state.setTheme(value); },
          child: Column(children: [
            for (final row in const [
              (ThemeMode.light, 'Светлая', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Тёмная', Icons.dark_mode_outlined),
              (ThemeMode.system, 'Автоматически', Icons.settings_brightness_outlined),
            ])
              RadioListTile<ThemeMode>(
                value: row.$1,
                title: Text(row.$2),
                secondary: Icon(row.$3),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ]),
        )),
        const SizedBox(height: 13),
        const OwnerHeading('Язык интерфейса'),
        const SizedBox(height: 8),
        OwnerCard(child: RadioGroup<String>(
          groupValue: state.language,
          onChanged: (value) {
            if (value != null) state.setLanguage(value);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Полный перевод подключим до выпуска.')),
            );
          },
          child: Column(children: [
            for (final value in ['Русский', 'Azərbaycan', 'English'])
              RadioListTile<String>(
                value: value,
                title: Text(value),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
          ]),
        )),
        const SizedBox(height: 12),
        OwnerCard(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const OwnerNotificationsScreen())),
          child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_outlined), title: Text('Уведомления'), trailing: Icon(Icons.chevron_right)),
        ),
        const SizedBox(height: 9),
        const OwnerCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.shield_outlined),
          title: Text('Безопасность'),
          subtitle: Text('Авторизация и биометрия подключаются отдельно'),
        )),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            state.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Выйти из демо'),
        ),
      ]),
    );
  }
}

class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  State<OwnerNotificationsScreen> createState() => _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  bool cash = true;
  bool sales = true;
  bool inventory = true;

  @override
  Widget build(BuildContext context) {
    if (OwnerScope.of(context).live) {
      return Scaffold(
        appBar: AppBar(title: const Text('Уведомления')),
        body: const OwnerScreenFrame(children: [
          OwnerHeading('Уведомления', caption: 'События ресторанов'),
          SizedBox(height: 14),
          OwnerCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_outlined, size: 30),
              SizedBox(height: 10),
              Text('Уведомления пока не подключены',
                style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Push и подписки подключим после настройки '
                  'защищённого серверного сервиса. '
                  'Демонстрационные события не показываются как настоящие.'),
            ],
          )),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления'), actions: [
        IconButton(
          tooltip: 'Настройки',
          onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true,
            builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
              return SafeArea(child: Padding(padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Подписки на уведомления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SwitchListTile(title: const Text('Кассовые смены'), value: cash,
                    onChanged: (v) { setState(() => cash = v); setSheetState(() {}); }),
                  SwitchListTile(title: const Text('Продажи'), value: sales,
                    onChanged: (v) { setState(() => sales = v); setSheetState(() {}); }),
                  SwitchListTile(title: const Text('Остатки на складах'), value: inventory,
                    onChanged: (v) { setState(() => inventory = v); setSheetState(() {}); }),
                  Text('Демо: переключатели пока не подключены к push-серверу.',
                    style: TextStyle(fontSize: 11, color: OwnerPalette.muted(ctx))),
                ]),
              ));
            }),
          ),
          icon: const Icon(Icons.tune),
        ),
      ]),
      body: OwnerScreenFrame(children: [
        const OwnerHeading('Последние события', caption: 'Push-уведомления подключим после серверной интеграции'),
        const SizedBox(height: 12),
        for (final e in const [
          (Icons.trending_down, 'Снижение выручки', 'Jelly Park • на 25% ниже вчерашнего дня'),
          (Icons.inventory_2_outlined, 'Низкий остаток', 'Помидоры • Основной склад'),
          (Icons.wallet, 'Смена закрыта', 'Касса 1 • Ресторан Баку'),
        ]) ...[
          OwnerCard(
            onTap: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(e.$2),
                content: Text('${e.$3}\n\nДемо события. Данные не получены из API.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(e.$1, color: OwnerPalette.accent(context)),
              title: Text(e.$2),
              subtitle: Text(e.$3, style: TextStyle(color: OwnerPalette.muted(context), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
