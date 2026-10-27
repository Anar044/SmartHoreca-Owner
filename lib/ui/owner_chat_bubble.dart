import 'package:flutter/material.dart';

import '../core/owner_theme.dart';

/// Chat messages have independent visual identities; reports and charts
/// remain full-width beneath the associated AI reply.
class OwnerChatBubble extends StatelessWidget {
  const OwnerChatBubble({
    super.key,
    required this.role,
    required this.text,
    this.onSpeak,
    this.onCopy,
    this.onPdf,
    this.copyTooltip = 'Скопировать ответ',
    this.pdfTooltip = 'Экспорт в PDF',
    this.speakTooltip = 'Озвучить ответ',
    this.stopSpeakTooltip = 'Остановить озвучивание',
    this.speaking = false,
  });

  final String role;
  final String text;
  final VoidCallback? onSpeak;
  final VoidCallback? onCopy;
  final VoidCallback? onPdf;
  final String copyTooltip;
  final String pdfTooltip;
  final String speakTooltip;
  final String stopSpeakTooltip;
  final bool speaking;

  bool get fromUser => role == 'user';

  @override
  Widget build(BuildContext context) {
    final dark = OwnerPalette.isDark(context);
    final background = fromUser
        ? (dark ? const Color(0xFF254B85) : const Color(0xFFDEEAFE))
        : OwnerPalette.surface(context);
    final foreground = OwnerPalette.text(context);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.87;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(fromUser ? 18 : 5),
              bottomRight: Radius.circular(fromUser ? 5 : 18),
            ),
            border: fromUser ? null : Border.all(
              color: dark ? const Color(0xFF2A3E57) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    fromUser ? Icons.person_outline_rounded
                        : Icons.smart_toy_outlined,
                    size: 17,
                    color: fromUser ? OwnerPalette.accent(context)
                        : OwnerPalette.muted(context),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    fromUser ? 'Вы' : 'AI Smart Horeca',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ]),
                const SizedBox(height: 9),
                SelectableText(
                  text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.43,
                    fontWeight: FontWeight.w400,
                    color: foreground,
                  ),
                ),
                if (!fromUser &&
                    (onSpeak != null || onCopy != null || onPdf != null)) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 3,
                      children: [
                        if (onCopy != null)
                          IconButton(
                            tooltip: copyTooltip,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.copy_outlined, size: 20),
                            onPressed: onCopy,
                          ),
                        if (onPdf != null)
                          IconButton(
                            tooltip: pdfTooltip,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.picture_as_pdf_outlined,
                                size: 20),
                            onPressed: onPdf,
                          ),
                        if (onSpeak != null)
                          IconButton(
                            tooltip: speaking ? stopSpeakTooltip : speakTooltip,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              speaking ? Icons.stop_circle_outlined
                                  : Icons.volume_up_outlined,
                              size: 21,
                            ),
                            onPressed: onSpeak,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
