import 'dart:io';

/// Prevent unsupported/corrupt audio from reaching the transcription service.
/// WAV is intentionally used on both mobile platforms: it contains a standard
/// RIFF header and does not depend on handset AAC/M4A container finalization.
class OwnerVoiceRecording {
  const OwnerVoiceRecording._();

  static const maxBytes = 15 * 1024 * 1024;
  static const minBytes = 3200; // ~0.1s at 16 kHz, mono, PCM16.
  static const minDuration = Duration(milliseconds: 800);

  static bool hasWavHeader(List<int> bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 &&
      bytes[2] == 0x46 && bytes[3] == 0x46 && // RIFF
      bytes[8] == 0x57 && bytes[9] == 0x41 &&
      bytes[10] == 0x56 && bytes[11] == 0x45; // WAVE

  static Future<bool> hasValidWavFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < minBytes || length > maxBytes) return false;
    final header = await file.openRead(0, 12)
        .fold<List<int>>(<int>[], (previous, next) => previous..addAll(next));
    return hasWavHeader(header);
  }
}
