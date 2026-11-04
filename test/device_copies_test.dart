import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/recorded_video.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/screens/recordings_screen.dart';
import 'package:teleprompter/services/device_video_library.dart';
import 'package:teleprompter/services/storage_service.dart';

class _FakeDeviceLibrary implements DeviceVideoLibrary {
  final List<String> savedIds = [];
  DeviceSaveOutcome outcome = DeviceSaveOutcome.saved;

  @override
  String get locationLabel => 'Movies/Cuevanta';

  @override
  bool isAvailable = true;

  @override
  Future<DeviceSaveOutcome> save(RecordedVideo take) async {
    if (outcome == DeviceSaveOutcome.saved) savedIds.add(take.id);
    return outcome;
  }
}

late Directory _videos;

RecordedVideo _take(String id, {bool isSavedToDevice = false, bool fileExists = true}) {
  final file = File('${_videos.path}/$id.mp4');
  if (fileExists) file.writeAsBytesSync([0, 1, 2]);
  return RecordedVideo(
    id: id,
    filePath: file.path,
    scriptId: 'glasses',
    scriptTitle: '03 · THU AM · Glasses',
    recordedAt: DateTime(2026, 11, 4, 9),
    durationSeconds: 40,
    fileSizeBytes: 3,
    takeNumber: int.parse(id.substring(1)),
    isSavedToDevice: isSavedToDevice,
  );
}

Future<StorageService> _storageWith(List<RecordedVideo> takes) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.resetForTesting();
  for (final take in takes) {
    await storage.addRecording(take);
  }
  return storage;
}

void main() {
  setUp(() => _videos = Directory.systemTemp.createTempSync('cuevanta_takes_'));
  tearDown(() => _videos.deleteSync(recursive: true));

  group('Saved-to-device flag and setting', () {
    test('takes saved before this option load as not copied', () {
      final map = _take('t1').toMap()..remove('isSavedToDevice');

      expect(RecordedVideo.fromMap(map).isSavedToDevice, isFalse);
    });

    test('the flag survives a save and load', () {
      expect(RecordedVideo.fromJson(_take('t1', isSavedToDevice: true).toJson()).isSavedToDevice, isTrue);
    });

    test('copying takes to the device is on by default', () {
      expect(TeleprompterSettings().saveTakesToDevice, isTrue);
      expect(TeleprompterSettings.fromMap({}).saveTakesToDevice, isTrue);
    });

    test('marking takes as copied only changes those takes', () async {
      final storage = await _storageWith([_take('t1'), _take('t2')]);

      await storage.markSavedToDevice({'t2'});

      final flags = {for (final t in await storage.getRecordings()) t.id: t.isSavedToDevice};
      expect(flags, {'t1': false, 't2': true});
    });
  });

  group('Recordings screen copies', () {
    late _FakeDeviceLibrary library;

    setUp(() => library = _FakeDeviceLibrary());

    Future<void> pumpScreen(WidgetTester tester, List<RecordedVideo> takes) async {
      await _storageWith(takes);
      await tester.pumpWidget(MaterialApp(home: RecordingsScreen(deviceLibrary: library)));
      await tester.pumpAndSettle();
    }

    testWidgets('offers to copy takes that only exist inside the app', (tester) async {
      await pumpScreen(tester, [_take('t1'), _take('t2'), _take('t3', isSavedToDevice: true)]);

      expect(find.textContaining('2 takes are only inside Cuevanta'), findsOneWidget);
    });

    testWidgets('takes whose files are gone are not offered', (tester) async {
      await pumpScreen(tester, [_take('t1', fileExists: false)]);

      expect(find.text('Save copies'), findsNothing);
    });

    testWidgets('"Save copies" copies every take and hides the offer', (tester) async {
      await pumpScreen(tester, [_take('t1'), _take('t2')]);

      await tester.tap(find.text('Save copies'));
      await tester.pumpAndSettle();

      expect(library.savedIds, unorderedEquals(['t1', 't2']));
      expect(find.text('Save copies'), findsNothing);
      expect(find.text('Copied 2 to Movies/Cuevanta'), findsOneWidget);
    });

    testWidgets('a refused permission stops copying and says so', (tester) async {
      library.outcome = DeviceSaveOutcome.permissionDenied;
      await pumpScreen(tester, [_take('t1'), _take('t2')]);

      await tester.tap(find.text('Save copies'));
      await tester.pumpAndSettle();

      expect(find.textContaining('permission not given'), findsOneWidget);
      expect(find.text('Save copies'), findsOneWidget);
    });

    testWidgets('no offer where saving to the device is not possible', (tester) async {
      library.isAvailable = false;
      await pumpScreen(tester, [_take('t1')]);

      expect(find.text('Save copies'), findsNothing);
    });

    testWidgets('deleting a copied take says the public copy is kept', (tester) async {
      await pumpScreen(tester, [_take('t1', isSavedToDevice: true)]);

      await tester.tap(find.byTooltip('Delete take'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The copy in Movies/Cuevanta is kept'), findsOneWidget);
    });
  });

  group('AndroidMoviesFolder', () {
    const channel = MethodChannel('cuevanta/public_videos');
    late List<MethodCall> calls;

    void answerWith(Future<Object?> Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    setUp(() => calls = []);
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('sends the take file and its readable name to Android', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      answerWith((_) async => 'content://media/external/video/media/1');
      final take = _take('t2');

      final outcome = await AndroidMoviesFolder().save(take);

      expect(outcome, DeviceSaveOutcome.saved);
      expect(calls.single.arguments, {'path': take.filePath, 'fileName': take.exportFileName});
    });

    test('a failed copy is reported as failed', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      answerWith((_) async => throw PlatformException(code: 'save_failed', message: 'disk full'));

      expect(await AndroidMoviesFolder().save(_take('t1')), DeviceSaveOutcome.failed);
    });

    test('takes go to Movies/Cuevanta', () {
      expect(AndroidMoviesFolder().locationLabel, 'Movies/Cuevanta');
    });
  });
}
