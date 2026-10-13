import 'package:flutter/material.dart';
import '../core/owner_theme.dart';
import '../core/owner_state.dart';
import '../ui/owner_components.dart';

class OwnerAiScreen extends StatefulWidget {
  const OwnerAiScreen({super.key});

  @override
  State<OwnerAiScreen> createState() => _OwnerAiScreenState();
}

class _OwnerAiScreenState extends State<OwnerAiScreen> {
  final controller = TextEditingController();
  String demoQuestion = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void showDemo(String question) {
    setState(() {
      demoQuestion = question;
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (OwnerScope.of(context).live) {
      return const OwnerScreenFrame(children: [
        OwnerRestaurantPicker(),
        SizedBox(height: 14),
        OwnerHeading('AI Smart Horeca Assistant'),
        SizedBox(height: 14),
        OwnerCard(child: Text(
          'Интерфейс AI утверждён. Реальные сообщения, история и голос '
          'будут подключены после серверной проверки прав доступа. '
          'До этого мы не будем показывать вымышленные AI-ответы.',
        )),
      ]);
    }
    final bg = OwnerPalette.surface(context);
    return Column(children: [
      Expanded(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const OwnerDemoNotice(),
          const SizedBox(height: 12),
          const OwnerRestaurantPicker(),
          const SizedBox(height: 14),
          OwnerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.smart_toy_outlined, color: OwnerPalette.accent(context), size: 27),
              const SizedBox(width: 10),
              const Text('AI Smart Horeca Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            const Text('Здравствуйте! Я помогу анализировать продажи, кассы и склады ваших ресторанов.'),
          ])),
          const SizedBox(height: 19),
          const OwnerHeading('Популярные вопросы'),
          const SizedBox(height: 11),
          for (final question in const [
            'Какая выручка сегодня?',
            'Сравни продажи ресторанов',
            'Какие товары заканчиваются?',
            'Покажи топ-5 блюд',
          ]) ...[
            OwnerCard(
              onTap: () => showDemo(question),
              child: Row(children: [
                Icon(Icons.auto_awesome_outlined, color: OwnerPalette.accent(context), size: 19),
                const SizedBox(width: 10),
                Expanded(child: Text(question, style: const TextStyle(fontSize: 13))),
                const Icon(Icons.chevron_right, size: 18),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          if (demoQuestion.isNotEmpty) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: OwnerPalette.accent(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(demoQuestion, style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 11),
            OwnerCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Пример аналитического ответа', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                const Text('В реальном приложении здесь будут данные из Smart Horeca, отфильтрованные по выбранным ресторанам.'),
                const SizedBox(height: 10),
                const OwnerBars(values: [23, 33, 29, 49, 38], labels: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт']),
                const SizedBox(height: 6),
                Text('Демонстрация: источник не подключён.', style: TextStyle(fontSize: 11, color: OwnerPalette.muted(context))),
              ],
            )),
          ],
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('История диалогов'),
                content: const Text('При подключении AI здесь будут личные разговоры пользователя. Демо не сохраняет переписку.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('История разговоров'),
          ),
        ],
      )),
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(child: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Напишите вопрос...'),
              onSubmitted: (s) { if (s.trim().isNotEmpty) showDemo(s.trim()); },
            )),
            IconButton(
              tooltip: 'Голосовой ввод (скоро)',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Голосовой ввод подключим к API на следующем этапе.'))),
              icon: Icon(Icons.mic_rounded, color: OwnerPalette.accent(context)),
            ),
            IconButton.filled(
              tooltip: 'Отправить демо-вопрос',
              onPressed: () {
                if (controller.text.trim().isNotEmpty) showDemo(controller.text.trim());
              },
              icon: const Icon(Icons.arrow_upward),
            ),
          ]),
        ),
      ),
    ]);
  }
}
