import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/recorded_video.dart';
import 'package:teleprompter/models/take_library.dart';

RecordedVideo _take(
  String id, {
  String scriptId = 'script-3',
  String scriptTitle = '03 · THU AM · Glasses that read silent words',
  int takeNumber = 1,
  bool isBest = false,
  DateTime? recordedAt,
}) {
  return RecordedVideo(
    id: id,
    filePath: '/takes/$id.mp4',
    scriptId: scriptId,
    scriptTitle: scriptTitle,
    recordedAt: recordedAt ?? DateTime(2026, 11, 4, 9),
    durationSeconds: 58,
    fileSizeBytes: 1024,
    takeNumber: takeNumber,
    isBest: isBest,
  );
}

void main() {
  group('Take names', () {
    test('imported titles keep the number and topic', () {
      expect(_take('a', takeNumber: 2).displayName, '03 · Glasses that read silent words · take 2');
    });

    test('plain titles are used whole', () {
      expect(_take('a', scriptTitle: 'Product launch pitch').displayName, 'Product launch pitch · take 1');
    });

    test('file names sort by date and are safe on every file system', () {
      expect(
        _take('a', takeNumber: 2, recordedAt: DateTime(2026, 11, 4)).exportFileName,
        '2026-11-04_03-glasses-that-read-silent-words_take-2.mp4',
      );
    });

    test('file names drop apostrophes and punctuation', () {
      expect(
        takeFileName(
          scriptTitle: "03 · THU AM · Google's AI you can't use: yet!",
          takeNumber: 1,
          recordedAt: DateTime(2026, 11, 5),
        ),
        '2026-11-05_03-googles-ai-you-cant-use-yet_take-1.mp4',
      );
    });

    test('very long titles are shortened in file names', () {
      final name = takeFileName(scriptTitle: 'word ' * 40, takeNumber: 1, recordedAt: DateTime(2026));

      expect(name.length, lessThan(90));
      expect(name, endsWith('_take-1.mp4'));
    });

    test('a title with no letters still gives a usable file name', () {
      expect(
        takeFileName(scriptTitle: '!!!', takeNumber: 3, recordedAt: DateTime(2026, 1, 2)),
        '2026-01-02_take_take-3.mp4',
      );
    });
  });

  group('TakeLibrary.nextTakeNumber', () {
    test('the first take of a script is take 1', () {
      expect(TakeLibrary.nextTakeNumber([], 'script-3'), 1);
    });

    test('counts on from the highest take of the same script only', () {
      final takes = [_take('a', takeNumber: 1), _take('b', takeNumber: 4), _take('c', scriptId: 'other', takeNumber: 9)];

      expect(TakeLibrary.nextTakeNumber(takes, 'script-3'), 5);
    });

    test('deleting the latest take does not reuse a lower gap', () {
      final remaining = [_take('a', takeNumber: 1), _take('c', takeNumber: 3)];

      expect(TakeLibrary.nextTakeNumber(remaining, 'script-3'), 4);
    });
  });

  group('TakeLibrary.numberUnnumberedTakes', () {
    test('numbers older takes in the order they were recorded', () {
      final takes = [
        _take('late', takeNumber: 0, recordedAt: DateTime(2026, 11, 4, 12)),
        _take('early', takeNumber: 0, recordedAt: DateTime(2026, 11, 4, 9)),
      ];

      final numbered = {for (final t in TakeLibrary.numberUnnumberedTakes(takes)) t.id: t.takeNumber};

      expect(numbered, {'early': 1, 'late': 2});
    });

    test('continues after numbers the script already uses', () {
      final takes = [_take('new', takeNumber: 2), _take('old', takeNumber: 0)];

      final old = TakeLibrary.numberUnnumberedTakes(takes).firstWhere((t) => t.id == 'old');

      expect(old.takeNumber, 3);
    });

    test('leaves the list untouched when every take is numbered', () {
      final takes = [_take('a', takeNumber: 1)];

      expect(TakeLibrary.numberUnnumberedTakes(takes), same(takes));
    });
  });

  group('TakeLibrary.toggleBestTake', () {
    test('stars a take', () {
      final result = TakeLibrary.toggleBestTake([_take('a')], 'a');

      expect(result.single.isBest, isTrue);
    });

    test('starring a take unstars the previous best of the same script', () {
      final result = TakeLibrary.toggleBestTake([_take('a', isBest: true), _take('b')], 'b');

      expect({for (final t in result) t.id: t.isBest}, {'a': false, 'b': true});
    });

    test('best takes of other scripts are left alone', () {
      final result = TakeLibrary.toggleBestTake([_take('x', scriptId: 'other', isBest: true), _take('b')], 'b');

      expect(result.firstWhere((t) => t.id == 'x').isBest, isTrue);
    });

    test('tapping the star again unstars it', () {
      final result = TakeLibrary.toggleBestTake([_take('a', isBest: true)], 'a');

      expect(result.single.isBest, isFalse);
    });

    test('an unknown take changes nothing', () {
      final takes = [_take('a')];

      expect(TakeLibrary.toggleBestTake(takes, 'missing'), same(takes));
    });
  });

  test('bestTakes lists starred takes newest first', () {
    final takes = [
      _take('old', isBest: true, recordedAt: DateTime(2026, 11, 3)),
      _take('plain'),
      _take('new', scriptId: 'other', isBest: true, recordedAt: DateTime(2026, 11, 5)),
    ];

    expect(TakeLibrary.bestTakes(takes).map((t) => t.id), ['new', 'old']);
  });

  test('take number and best flag survive a save and load', () {
    final restored = RecordedVideo.fromJson(_take('a', takeNumber: 7, isBest: true).toJson());

    expect(restored.takeNumber, 7);
    expect(restored.isBest, isTrue);
  });
}
