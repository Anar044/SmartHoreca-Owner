import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_horeca_owner/core/owner_snapshot_store.dart';

void main() {
  late DateTime now;
  String? saved;
  late OwnerSnapshotStore store;
  Map<String, dynamic> sample() => {'success': true,
    'updatedAt': now.toIso8601String(), 'metrics': {'revenue': 120}};
  setUp(() {
    saved = null;
    now = DateTime.utc(2026, 11, 12, 12);
    store = OwnerSnapshotStore(read: () async => saved,
      write: (value) async { saved = value; },
      remove: () async { saved = null; }, clock: () => now);
  });

  test('restores exact verified identity and source revision after restart', () async {
    await store.activate('user1:workspace1:dept1:revision1');
    await store.remember('summary:exact-dates', sample());
    now = now.add(const Duration(minutes: 5));
    final result = await store.activate('user1:workspace1:dept1:revision1');
    expect(result['summary:exact-dates']?.data['metrics']['revenue'], 120);
    expect(result['summary:exact-dates']?.savedAt, now.subtract(const Duration(minutes: 5)));
  });

  test('different user, permissions, workspace or source cannot restore data', () async {
    for (final binding in ['user2:w1:d1:r1', 'u1:w2:d1:r1',
      'u1:w1:d2:r1', 'u1:w1:d1:r2']) {
      await store.activate('u1:w1:d1:r1');
      await store.remember('summary:exact', sample());
      expect(await store.activate(binding), isEmpty);
      expect(jsonDecode(saved!)['entries'], isEmpty);
    }
  });

  test('expires at 24 hours, rejects corrupt storage and never stores AI or receipts', () async {
    await store.activate('verified');
    await store.remember('summary:exact', sample());
    await store.remember('order:123', sample());
    await store.remember('assistant:dialog', sample());
    expect((jsonDecode(saved!)['entries'] as Map).keys, ['summary:exact']);
    now = now.add(const Duration(hours: 25));
    expect(await store.activate('verified'), isEmpty);
    saved = 'corrupt';
    expect(await store.activate('verified'), isEmpty);
  });

  test('logout serializes removal after a pending save without resurrection', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var slow = false;
    store = OwnerSnapshotStore(read: () async => saved,
      write: (value) async {
        if (slow) { started.complete(); await release.future; }
        saved = value;
      }, remove: () async { saved = null; }, clock: () => now);
    await store.activate('verified');
    slow = true;
    final writing = store.remember('summary:exact', sample());
    await started.future;
    final clearing = store.clear();
    release.complete();
    await Future.wait([writing, clearing]);
    await store.remember('summary:late', sample());
    expect(saved, isNull);
  });

  test('bounds persisted snapshots and rejects unsuccessful or undated data', () async {
    await store.activate('verified');
    for (var i = 0; i < 20; i++) {
      await store.remember('summary:$i', sample());
    }
    await store.remember('summary:failed', {'success': false});
    await store.remember('summary:undated', {'success': true});
    expect((jsonDecode(saved!)['entries'] as Map).length, 16);
    expect((jsonDecode(saved!)['entries'] as Map).containsKey('summary:0'), isFalse);
    expect(utf8.encode(saved!).length, lessThanOrEqualTo(OwnerSnapshotStore.maxBytes));
  });
}
