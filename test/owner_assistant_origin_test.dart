import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_backend.dart';

void main() {
  test('only the exact feature endpoints use their configured backends', () {
    expect(OwnerBackend.endpoint('/api/mobile/v1/assistant').toString(),
        '${OwnerBackend.assistantApiBase}/api/mobile/v1/assistant');
    expect(OwnerBackend.endpoint(OwnerBackend.olapReportsPath).toString(),
        '${OwnerBackend.olapApiBase}${OwnerBackend.olapReportsPath}');
    for (final path in [
      '/api/mobile/v1/dashboard',
      '/api/mobile/v1/voice',
      '/api/mobile/v1/assistant-other',
      '/api/mobile/v1/olap-reports-other',
    ]) {
      expect(OwnerBackend.endpoint(path).toString(),
          '${OwnerBackend.apiBase}$path');
    }
  });
}
