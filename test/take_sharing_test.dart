import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/recorded_video.dart';
import 'package:teleprompter/services/take_sharing.dart';
import 'package:teleprompter/widgets/share_action.dart';

class _FakeSheet implements VideoShareSheet {
  final List<List<String>> openedWith = [];
  Completer<void>? holdOpen;
  bool reportMissingCopy = false;

  @override
  Future<void> open(List<RecordedVideo> takes, String subject) async {
    if (reportMissingCopy) throw const MissingPublicCopyException('deleted in Gallery');
    openedWith.add([for (final take in takes) take.id]);
    await holdOpen?.future;
  }
}

late Directory _videos;

RecordedVideo _take(String id, {String? publicCopyUri, bool appFileExists = true}) {
  final file = File('${_videos.path}/$id.mp4');
  if (appFileExists) file.writeAsBytesSync([1, 2, 3]);
  return RecordedVideo(
    id: id,
    filePath: file.path,
    scriptId: 'glasses',
    scriptTitle: '03 · THU AM · Glasses',
    recordedAt: DateTime(2026, 11, 4),
    durationSeconds: 30,
    fileSizeBytes: 3,
    publicCopyUri: publicCopyUri,
    isSavedToDevice: publicCopyUri != null,
  );
}

Future<List<RecordedVideo>> _unchanged(List<RecordedVideo> takes) async => takes;

void main() {
  late _FakeSheet direct;
  late _FakeSheet copying;
  late TakeSharing sharing;

  setUp(() {
    _videos = Directory.systemTemp.createTempSync('cuevanta_share_');
    direct = _FakeSheet();
    copying = _FakeSheet();
    sharing = TakeSharing(directSheet: direct, copyingSheet: copying, refresh: _unchanged);
  });
  tearDown(() => _videos.deleteSync(recursive: true));

  group('TakeSharing', () {
    test('takes with a Movies copy are shared straight from it, without copying', () async {
      final attempt = await sharing.share([_take('a', publicCopyUri: 'content://media/1')]);

      expect(attempt, ShareAttempt.opened);
      expect(direct.openedWith, [['a']]);
      expect(copying.openedWith, isEmpty);
    });

    test('a take without a Movies copy uses the copying share for the whole batch', () async {
      await sharing.share([_take('a', publicCopyUri: 'content://media/1'), _take('b')]);

      expect(direct.openedWith, isEmpty);
      expect(copying.openedWith, [['a', 'b']]);
    });

    test('a file path from older Android is not shared directly', () async {
      await sharing.share([_take('a', publicCopyUri: '/storage/emulated/0/Movies/Cuevanta/a.mp4')]);

      expect(copying.openedWith, [['a']]);
    });

    test('falls back to the app copy when the Movies copy was deleted', () async {
      direct.reportMissingCopy = true;

      final attempt = await sharing.share([_take('a', publicCopyUri: 'content://media/1')]);

      expect(attempt, ShareAttempt.opened);
      expect(copying.openedWith, [['a']]);
    });

    test('reports nothing to share when no copy exists anywhere', () async {
      final attempt = await sharing.share([_take('a', appFileExists: false)]);

      expect(attempt, ShareAttempt.nothingToShare);
      expect(copying.openedWith, isEmpty);
    });

    test('uses the latest stored version of a take', () async {
      final stale = _take('a');
      final saved = _take('a', publicCopyUri: 'content://media/1');
      sharing = TakeSharing(
        directSheet: direct,
        copyingSheet: copying,
        refresh: (takes) async => [saved],
      );

      await sharing.share([stale]);

      expect(direct.openedWith, [['a']]);
    });

    test('a second tap while preparing is ignored', () async {
      copying.holdOpen = Completer<void>();
      final first = sharing.share([_take('a')]);

      expect(sharing.isPreparing.value, isTrue);
      expect(await sharing.share([_take('b')]), ShareAttempt.alreadyInProgress);

      copying.holdOpen!.complete();
      expect(await first, ShareAttempt.opened);
      expect(sharing.isPreparing.value, isFalse);
      expect(copying.openedWith, [['a']]);
    });
  });

  group('PublicCopyShareSheet', () {
    const channel = MethodChannel('cuevanta/public_videos');
    late List<MethodCall> calls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = [];
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    void answerWith(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    test('sends every Movies copy and the subject to Android', () async {
      answerWith((_) async => null);

      await const PublicCopyShareSheet().open(
        [_take('a', publicCopyUri: 'content://media/1'), _take('b', publicCopyUri: 'content://media/2')],
        '2 Cuevanta takes',
      );

      expect(calls.single.method, 'shareVideos');
      expect(calls.single.arguments, {
        'uris': ['content://media/1', 'content://media/2'],
        'subject': '2 Cuevanta takes',
      });
    });

    test('a deleted Movies copy is reported as missing', () async {
      answerWith((_) async => throw PlatformException(code: 'missing_public_copy'));

      expect(
        () => const PublicCopyShareSheet().open([_take('a', publicCopyUri: 'content://media/1')], 'x'),
        throwsA(isA<MissingPublicCopyException>()),
      );
    });
  });

  group('ShareAction', () {
    Widget buttonFor(String label, List<RecordedVideo> takes) => ShareAction(
          takes: takes,
          sharing: sharing,
          builder: (context, isPreparing, onPressed) => TextButton(
            onPressed: onPressed,
            child: Text(isPreparing ? '$label preparing' : label),
          ),
        );

    testWidgets('only the tapped button shows preparing, and all are disabled meanwhile', (tester) async {
      copying.holdOpen = Completer<void>();
      final takeA = _take('a');
      final takeB = _take('b');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Column(children: [buttonFor('A', [takeA]), buttonFor('B', [takeB])])),
      ));

      await tester.tap(find.text('A'));
      await tester.pump();

      expect(find.text('A preparing'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'B')).onPressed, isNull);

      copying.holdOpen!.complete();
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('explains when the video files are gone', (tester) async {
      final gone = _take('a', appFileExists: false);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: buttonFor('Share', [gone]))));

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(find.text('Those video files are no longer on this device.'), findsOneWidget);
    });
  });
}
