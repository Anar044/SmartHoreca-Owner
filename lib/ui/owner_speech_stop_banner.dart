import 'package:flutter/material.dart';

import '../core/owner_theme.dart';

/// Stays above the scrollable conversation until the native TTS engine stops.
/// Unlike a control inside a long chat bubble, this can always be reached.
class OwnerSpeechStopBanner extends StatelessWidget {
  const OwnerSpeechStopBanner({super.key, required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OwnerPalette.isDark(context)
          ? OwnerPalette.darkRaised : OwnerPalette.lightSurface,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(Icons.volume_up_rounded,
            color: OwnerPalette.accent(context), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('AI озвучивает ответ…',
              maxLines: 2,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('owner-tts-stop'),
            onPressed: onStop,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text('Стоп'),
          ),
        ]),
      ),
    );
  }
}
