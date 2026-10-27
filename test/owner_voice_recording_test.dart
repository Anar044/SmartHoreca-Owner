import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_voice_recording.dart';

void main() {
  test('accepts standard finalized RIFF WAVE header', () {
    final data = <int>[0x52,0x49,0x46,0x46,0,0,0,0,
      0x57,0x41,0x56,0x45];
    expect(OwnerVoiceRecording.hasWavHeader(data), isTrue);
  });

  test('rejects truncated or misidentified AAC/M4A payload', () {
    expect(OwnerVoiceRecording.hasWavHeader([]), isFalse);
    expect(OwnerVoiceRecording.hasWavHeader(
      <int>[0,0,0,0,0x66,0x74,0x79,0x70,0x4D,0x34,0x41,0x20]), isFalse);
  });

  test('minimum recording duration prevents immediate empty uploads', () {
    expect(OwnerVoiceRecording.minDuration.inMilliseconds,
      greaterThanOrEqualTo(700));
    expect(OwnerVoiceRecording.maxBytes, lessThan(16 * 1024 * 1024));
  });
}
