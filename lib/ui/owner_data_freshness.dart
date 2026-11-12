import 'package:flutter/material.dart';
import '../core/owner_l10n.dart';
import '../core/owner_state.dart';
import '../core/owner_theme.dart';

/// Always show the source timestamp, including during background refresh.
class OwnerDataFreshness extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool updating;
  const OwnerDataFreshness({super.key, required this.data, this.updating = false});
  @override
  Widget build(BuildContext context) {
    final language = OwnerScope.of(context).language;
    final date = DateTime.tryParse('${data['updatedAt'] ?? ''}')?.toLocal();
    final time = date == null ? '—' : '${OwnerState.formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(
      '${OwnerL10n.tr(language, 'Данные на')}: $time'
      '${updating ? ' · ${OwnerL10n.tr(language, 'Обновляем…')}' : ''}',
      style: TextStyle(fontSize: 11, color: OwnerPalette.muted(context)),
    ));
  }
}
