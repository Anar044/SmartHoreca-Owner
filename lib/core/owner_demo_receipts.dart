/// Offline UI preview receipts, never used for real financial calculations.
class OwnerDemoLine {
  final String name;
  final double amount;
  const OwnerDemoLine(this.name, this.amount);
}

class OwnerDemoTender {
  final String name;
  final double amount;
  const OwnerDemoTender(this.name, this.amount);
}

class OwnerDemoReceipt {
  final String cashName;
  final String number;
  final String time;
  final List<OwnerDemoLine> lines;
  final List<OwnerDemoTender> tenders;

  const OwnerDemoReceipt({
    required this.cashName,
    required this.number,
    required this.time,
    required this.lines,
    required this.tenders,
  });

  double get amount =>
      lines.fold<double>(0, (sum, line) => sum + line.amount);
  double get paid =>
      tenders.fold<double>(0, (sum, tender) => sum + tender.amount);
  String get paymentLabel =>
      tenders.map((t) => t.name).join(' + ');

  static const samples = [
    OwnerDemoReceipt(
      cashName: 'Касса 1', number: '№25680', time: '14:32',
      lines: [
        OwnerDemoLine('Стейк Рибай', 42),
        OwnerDemoLine('Салат Цезарь', 12),
        OwnerDemoLine('Лимонад', 18),
        OwnerDemoLine('Хлеб', 3),
      ],
      tenders: [
        OwnerDemoTender('Карта', 50),
        OwnerDemoTender('Наличные', 25),
      ],
    ),
    OwnerDemoReceipt(
      cashName: 'Касса 1', number: '№25679', time: '14:28',
      lines: [OwnerDemoLine('Паста', 16.30), OwnerDemoLine('Чай', 8)],
      tenders: [OwnerDemoTender('Наличные', 24.30)],
    ),
    OwnerDemoReceipt(
      cashName: 'Касса 1', number: '№25678', time: '14:25',
      lines: [OwnerDemoLine('Суп', 18)],
      tenders: [OwnerDemoTender('Карта', 18)],
    ),
    OwnerDemoReceipt(
      cashName: 'Касса 2', number: '№25695', time: '15:08',
      lines: [
        OwnerDemoLine('Пицца', 28),
        OwnerDemoLine('Лимонад', 8),
      ],
      tenders: [OwnerDemoTender('Карта', 36)],
    ),
    OwnerDemoReceipt(
      cashName: 'Касса 2', number: '№25693', time: '14:50',
      lines: [OwnerDemoLine('Сэндвич', 19.50)],
      tenders: [OwnerDemoTender('Наличные', 19.50)],
    ),
    OwnerDemoReceipt(
      cashName: 'Касса 3', number: '№25582', time: '21:11',
      lines: [OwnerDemoLine('Салат', 14), OwnerDemoLine('Сок', 5)],
      tenders: [OwnerDemoTender('Карта', 19)],
    ),
  ];

  static List<OwnerDemoReceipt> forCash(String cashName) =>
      samples.where((receipt) => receipt.cashName == cashName).toList();
}
