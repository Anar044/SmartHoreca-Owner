import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_state.dart';
import 'package:smart_horeca_owner/core/owner_theme.dart';
import 'package:smart_horeca_owner/screens/owner_assistant_visuals.dart';
import 'package:smart_horeca_owner/ui/owner_brand.dart';
import 'package:smart_horeca_owner/ui/owner_chat_bubble.dart';
import 'package:smart_horeca_owner/ui/owner_components.dart';

/// Capture the approved Flutter components at an Apple-supported 6.9" iPhone
/// resolution, with entirely invented marketing sample data. This tool is
/// never compiled into the signed release and never calls production APIs.
const captureEnabled = bool.fromEnvironment('SH_STORE_CAPTURE', defaultValue: false);
const captureKey = ValueKey<String>('app-store-capture');

String label(bool ru, String en, String russian) => ru ? russian : en;

class StorePage extends StatelessWidget {
  final int page;
  final bool russian;
  const StorePage({super.key, required this.page, required this.russian});

  @override
  Widget build(BuildContext context) {
    final cards = switch (page) {
      0 => _dashboard(context),
      1 => _cash(context),
      2 => _reports(context),
      _ => _assistant(context),
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 16,
        title: Row(children: [
          const OwnerBrandMark(size: 42),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SH Owner',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text(label(russian, 'Your business under control',
                'Ваш бизнес под контролем'),
              style: const TextStyle(fontSize: 11)),
          ]),
        ]),
        actions: const [
          Icon(Icons.notifications_none_outlined, size: 25),
          SizedBox(width: 18),
          Icon(Icons.account_circle_outlined, size: 27),
          SizedBox(width: 20),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
        children: cards,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: OwnerPalette.accent(context),
        unselectedItemColor: OwnerPalette.muted(context),
        currentIndex: page,
        showUnselectedLabels: true,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            label: label(russian, 'Home', 'Главная')),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: label(russian, 'Cash', 'Кассы')),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            label: label(russian, 'Reports', 'Отчёты')),
          const BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined), label: 'AI'),
        ],
      ),
    );
  }

  Widget _title(String title, {String? subtitle}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 23,
        fontWeight: FontWeight.w800)),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(
          fontSize: 13, color: Color(0xFF64748B))),
      ],
    ],
  );

  Widget _scope() => OwnerCard(child: Row(children: [
    const Icon(Icons.store_outlined, color: Color(0xFF2563EB), size: 21),
    const SizedBox(width: 9),
    Expanded(child: Text(label(russian, '2 selected restaurants',
      'Выбрано ресторанов: 2'),
      style: const TextStyle(fontWeight: FontWeight.w600))),
    const Icon(Icons.keyboard_arrow_down),
  ]));

  Widget _period() => Row(children: [
    for (final t in [
      label(russian, 'Today', 'Сегодня'),
      label(russian, 'Yesterday', 'Вчера'),
      label(russian, '7 days', '7 дней'),
    ]) ...[
      Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: t == label(russian, 'Today', 'Сегодня')
              ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(t, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ],
  ]);

  List<Widget> _dashboard(BuildContext context) => [
    _title(label(russian, 'Business overview', 'Обзор бизнеса'),
      subtitle: label(russian, 'Today across selected restaurants',
        'Сегодня по выбранным ресторанам')),
    const SizedBox(height: 18), _scope(), const SizedBox(height: 14),
    _period(), const SizedBox(height: 21),
    Row(children: [
      Expanded(child: OwnerMetric(label(russian, 'Revenue', 'Выручка'),
        '12 030 AZN', trend: '+12.5%')),
      const SizedBox(width: 12),
      Expanded(child: OwnerMetric(label(russian, 'Checks', 'Чеков'),
        '184', trend: '+8%')),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: OwnerMetric(label(russian, 'Average check', 'Средний чек'),
        '65.38 AZN')),
      const SizedBox(width: 12),
      Expanded(child: OwnerMetric(label(russian, 'Discounts', 'Скидки'),
        '420 AZN')),
    ]),
    const SizedBox(height: 17),
    OwnerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label(russian, 'Sales by hour', 'Продажи по часам'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 17),
      const OwnerBars(values: [18, 32, 56, 74, 90, 77, 58],
        labels: ['09', '11', '13', '15', '17', '19', '21']),
    ])),
    const SizedBox(height: 17),
    _title(label(russian, 'Restaurant comparison', 'Сравнение ресторанов')),
    const SizedBox(height: 12),
    _line('North Restaurant', '8 420 AZN'),
    const SizedBox(height: 8),
    _line('Central Restaurant', '3 610 AZN'),
  ];

  Widget _line(String name, String value, {IconData icon = Icons.store_outlined}) =>
      OwnerCard(child: Row(children: [
        Icon(icon, color: const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]));

  List<Widget> _cash(BuildContext context) => [
    _title(label(russian, 'Cash registers', 'Кассы'),
      subtitle: label(russian, 'Shifts and sales information',
        'Смены и продажи')),
    const SizedBox(height: 18), _scope(), const SizedBox(height: 18),
    Row(children: [
      Expanded(child: OwnerMetric(label(russian, 'Open shifts',
        'Открытых смен'), '2')),
      const SizedBox(width: 12),
      Expanded(child: OwnerMetric(label(russian, 'Sales',
        'Продажи'), '12 030 AZN')),
    ]),
    const SizedBox(height: 22),
    _title(label(russian, 'Active registers', 'Активные кассы')),
    const SizedBox(height: 13),
    _cashCard('CASH 01', 'North Restaurant', '8 420 AZN'),
    const SizedBox(height: 13),
    _cashCard('CASH 02', 'Central Restaurant', '3 610 AZN'),
    const SizedBox(height: 19),
    OwnerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label(russian, 'Cash sales', 'Продажи по кассам'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 18),
      const OwnerRevenueDiagram(
        values: [8420, 3610], labels: ['CASH 01', 'CASH 02'],
        valueLabels: ['8420.00', '3610.00'],
        labelWidth: 92),
    ])),
  ];

  Widget _cashCard(String name, String restaurant, String sales) =>
    OwnerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.point_of_sale_outlined, color: Color(0xFF2563EB)),
        const SizedBox(width: 9),
        Expanded(child: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        Container(
          decoration: BoxDecoration(color: const Color(0xFFDBFCE7),
            borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Text(label(russian, 'Open', 'Открыта'),
            style: const TextStyle(color: Color(0xFF15803D), fontSize: 11)),
        ),
      ]),
      const SizedBox(height: 8),
      Text(restaurant, style: const TextStyle(
        color: Color(0xFF64748B), fontSize: 12)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label(russian, 'Shift sales', 'Продажи смены')),
        Text(sales, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    ]));

  List<Widget> _reports(BuildContext context) => [
    _title(label(russian, 'Reports & analytics', 'Отчёты и аналитика'),
      subtitle: label(russian, 'Your business, clearly presented',
        'Показатели вашего бизнеса')),
    const SizedBox(height: 19), _scope(), const SizedBox(height: 15),
    _period(), const SizedBox(height: 19),
    for (final data in <(IconData,String,String)>[
      (Icons.restaurant_menu, 'Dishes and categories', 'Блюда и категории'),
      (Icons.percent, 'Discounts and surcharges', 'Скидки и наценки'),
      (Icons.calculate_outlined, 'Food cost', 'Себестоимость'),
      (Icons.account_balance_wallet_outlined, 'Profit & loss', 'Прибыли и убытки'),
      (Icons.account_tree_outlined, 'Cash and payments', 'Касса и способы оплаты'),
      (Icons.warehouse_outlined, 'Inventory balances', 'Остатки на складах'),
    ]) ...[
      OwnerCard(child: Row(children: [
        Container(width: 45, height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFE9F0FA)),
          child: Icon(data.$1, color: const Color(0xFF2563EB))),
        const SizedBox(width: 13),
        Expanded(child: Text(label(russian, data.$2, data.$3),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        const Icon(Icons.chevron_right),
      ])),
      const SizedBox(height: 10),
    ],
  ];

  List<Widget> _assistant(BuildContext context) => [
    _title('AI Smart Horeca Assistant',
      subtitle: label(russian, 'Business answers in your language',
        'Аналитика на вашем языке')),
    const SizedBox(height: 16), _scope(), const SizedBox(height: 17),
    Align(alignment: Alignment.centerRight,
      child: OwnerChatBubble(role:'user',
        userLabel: label(russian, 'You', 'Вы'),
        text: label(russian,
          'Show sales by cash register as a chart.',
          'Покажи продажи по кассам в виде графика.'))),
    const SizedBox(height: 13),
    OwnerChatBubble(role:'assistant',
      text: label(russian,
        'Sales from two registers total 12 030 AZN.',
        'Продажи по двум кассам составили 12 030 AZN.'),
      onCopy: () {}, onPdf: () {}, onSpeak: () {}),
    const SizedBox(height: 12),
    OwnerAssistantVisuals(
      charts: [{
        'title': label(russian, 'Cash register sales', 'Продажи по кассам'),
        'subtitle': label(russian, 'Today · AZN', 'Сегодня · AZN'),
        'series': const [{
          'name': 'Sales',
          'data': [
            {'label': 'CASH 01', 'value': 8420},
            {'label': 'CASH 02', 'value': 3610},
          ],
        }],
      }],
      onCopy: () {}, onPdf: () {},
    ),
  ];
}

Future<void> saveScreenshot(WidgetTester tester, String filename) async {
  await tester.pumpAndSettle();
  // Asynchronous image encoding and file I/O must run outside the test
  // binding's fake clock, otherwise screenshot capture may never complete.
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('PNG encoding returned null');
      final directory = Directory('build/app_store_screenshots');
      await directory.create(recursive:true);
      await File('${directory.path}/$filename').writeAsBytes(
        png.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

bool _storeFontLoaded = false;

Future<void> ensureStoreFont(WidgetTester tester) async {
  if (_storeFontLoaded) return;
  await tester.runAsync(() async {
    final bytes = await File('build/store_font/SpaceGrotesk.ttf').readAsBytes();
    final loader = FontLoader('StoreSpaceGrotesk')
      ..addFont(Future.value(
        ByteData.sublistView(bytes),
      ));
    await loader.load();
    final iconBytes = await File(
      'build/store_font/MaterialIcons-Regular.otf',
    ).readAsBytes();
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await icons.load();
    final cyrillicBytes = await File(
      'build/store_font/NotoSans.ttf',
    ).readAsBytes();
    final cyrillic = FontLoader('StoreNotoSans')
      ..addFont(Future.value(ByteData.sublistView(cyrillicBytes)));
    await cyrillic.load();
    _storeFontLoaded = true;
  });
}

void main() {
  final pages = ['01-home', '02-cash', '03-reports', '04-ai'];
  for (final device in ['iphone', 'ipad13']) {
    final iPad = device == 'ipad13';
    for (final language in ['en', 'ru']) {
      for (var page = 0; page < pages.length; page++) {
        testWidgets('App Store screenshot $device $language ${pages[page]}',
            (tester) async {
        // Render at Apple's actual 13-inch iPad resolution. This is an
        // independent Flutter layout, never a stretched iPhone bitmap.
        tester.view.physicalSize = iPad
          ? const Size(2064, 2752) : const Size(1320, 2868);
        tester.view.devicePixelRatio = iPad ? 2 : 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = OwnerState();
        state.language = language == 'ru' ? 'Русский' : 'English';
        addTearDown(state.dispose);
        if (captureEnabled) await ensureStoreFont(tester);
        await tester.pumpWidget(OwnerScope(
          state: state,
          child: MaterialApp(
            debugShowCheckedModeBanner:false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF3F6FC),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2563EB)),
              fontFamily: language == 'ru'
                ? 'StoreNotoSans' : 'StoreSpaceGrotesk',
            ),
            home: RepaintBoundary(
              key:captureKey,
              child: StorePage(page:page, russian:language=='ru'),
            ),
          ),
        ));
        if (captureEnabled) {
          // The first image decode is asynchronous even after pumpAndSettle.
          // Wait for the exact production brand asset before the first shot.
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/brand/sh-owner-original.png'),
              tester.element(find.byKey(captureKey)),
            );
          });
          await tester.pump();
          final suffix = iPad ? '2064x2752' : '1320x2868';
          await saveScreenshot(tester,
            '${pages[page]}-$language-$suffix.png');
        } else {
          await tester.pumpAndSettle();
          expect(find.text('SH Owner'), findsOneWidget);
        }
        }, skip:!captureEnabled);
      }
    }
  }
}
