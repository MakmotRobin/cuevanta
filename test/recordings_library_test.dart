import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/recorded_video.dart';
import 'package:teleprompter/screens/recordings_screen.dart';
import 'package:teleprompter/services/storage_service.dart';

const String _recordingsKey = 'teleprompter_recordings_v1';

RecordedVideo _take(String id, String scriptId, String title, {int takeNumber = 1, int hour = 9}) {
  return RecordedVideo(
    id: id,
    filePath: '/missing/$id.mp4',
    scriptId: scriptId,
    scriptTitle: title,
    recordedAt: DateTime(2026, 11, 4, hour),
    durationSeconds: 45,
    fileSizeBytes: 2048,
    takeNumber: takeNumber,
  );
}

/// A take as saved by builds before numbering existed (no takeNumber field).
String _legacyTakeJson(String id, int hour) {
  final map = _take(id, 'glasses', '03 · THU AM · Glasses').toMap()
    ..remove('takeNumber')
    ..remove('isBest')
    ..['recordedAt'] = DateTime(2026, 11, 3, hour).toIso8601String();
  return jsonEncode(map);
}

Future<StorageService> _storageWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final storage = StorageService();
  await storage.resetForTesting();
  return storage;
}

void main() {
  group('StorageService takes', () {
    test('takes saved before numbering are numbered by recording time', () async {
      final storage = await _storageWith({_recordingsKey: [_legacyTakeJson('second', 11), _legacyTakeJson('first', 9)]});

      final numbers = {for (final t in await storage.getRecordings()) t.id: t.takeNumber};

      expect(numbers, {'first': 1, 'second': 2});
    });

    test('numbering older takes is saved, not redone on every read', () async {
      final storage = await _storageWith({_recordingsKey: [_legacyTakeJson('only', 9)]});
      await storage.getRecordings();

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getStringList(_recordingsKey)!.single, contains('"takeNumber":1'));
    });

    test('the next take continues the script\'s numbering', () async {
      final storage = await _storageWith({});
      await storage.addRecording(_take('a', 'glasses', 'Glasses', takeNumber: 2));

      expect(await storage.nextTakeNumber('glasses'), 3);
      expect(await storage.nextTakeNumber('another-script'), 1);
    });

    test('starring a take is saved', () async {
      final storage = await _storageWith({});
      await storage.addRecording(_take('a', 'glasses', 'Glasses'));

      await storage.toggleBestTake('a');

      expect((await storage.getRecordings()).single.isBest, isTrue);
    });
  });

  group('Recordings screen', () {
    Future<void> pumpWithTakes(WidgetTester tester, List<RecordedVideo> takes) async {
      final storage = await _storageWith({});
      for (final take in takes) {
        await storage.addRecording(take);
      }
      await tester.pumpWidget(const MaterialApp(home: RecordingsScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('groups takes under their script', (tester) async {
      await pumpWithTakes(tester, [
        _take('g1', 'glasses', '03 · THU AM · Glasses that read silent words'),
        _take('g2', 'glasses', '03 · THU AM · Glasses that read silent words', takeNumber: 2, hour: 10),
        _take('t1', 'tokens', 'S2 · SPARE · Learn what a token is', hour: 8),
      ]);

      expect(find.text('03 · GLASSES THAT READ SILENT WORDS'), findsOneWidget);
      expect(find.text('S2 · LEARN WHAT A TOKEN IS'), findsOneWidget);
      expect(find.text('Take 2'), findsOneWidget);
    });

    testWidgets('shows "Share best takes" only once a take is starred', (tester) async {
      await pumpWithTakes(tester, [_take('g1', 'glasses', '03 · THU AM · Glasses')]);
      expect(find.textContaining('SHARE BEST TAKES'), findsNothing);

      await tester.tap(find.byTooltip('Mark as best take'));
      await tester.pumpAndSettle();

      expect(find.text('SHARE BEST TAKES (1)'), findsOneWidget);
      expect(find.byTooltip('Best take (tap to clear)'), findsOneWidget);
    });
  });
}
