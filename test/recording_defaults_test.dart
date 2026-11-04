import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/screens/studio_recording_screen.dart';
import 'package:teleprompter/services/recording_format.dart';
import 'package:teleprompter/services/storage_service.dart';

final Script _script = Script(
  id: 'studio',
  title: 'Studio',
  content: 'A short line to read.',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('Recording quality setting', () {
    test('defaults to 1080p', () {
      expect(TeleprompterSettings().recordingQuality, RecordingQuality.fullHd1080);
    });

    test('survives a save and load', () {
      final saved = TeleprompterSettings(recordingQuality: RecordingQuality.uhd4k).toJson();

      expect(TeleprompterSettings.fromJson(saved).recordingQuality, RecordingQuality.uhd4k);
    });

    test('settings saved before this option existed load as 1080p', () {
      expect(TeleprompterSettings.fromMap({}).recordingQuality, RecordingQuality.fullHd1080);
    });
  });

  group('RecordingFormat', () {
    test('1080p uses the ~1080p camera preset', () {
      expect(
        RecordingFormat.forQuality(RecordingQuality.fullHd1080).resolutionPreset,
        ResolutionPreset.veryHigh,
      );
    });

    test('higher quality never lowers the bitrate', () {
      final bitrates = [
        for (final quality in RecordingQuality.values) RecordingFormat.forQuality(quality).videoBitrate,
      ];

      expect(bitrates, orderedEquals([...bitrates]..sort()));
    });

    test('records at 30 frames per second', () {
      expect(RecordingFormat.framesPerSecond, 30);
    });
  });

  group('Studio screen', () {
    late List<Object?> orientationRequests;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StorageService().resetForTesting();
      orientationRequests = [];
    });

    Future<void> pumpStudio(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') orientationRequests.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StudioRecordingScreen(script: _script)),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      // Camera start-up resolves on real async I/O, which the fake clock doesn't advance.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('locks the screen to portrait for vertical video', (tester) async {
      await pumpStudio(tester);

      expect(orientationRequests.first, ['DeviceOrientation.portraitUp']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('restores every orientation when leaving', (tester) async {
      await pumpStudio(tester);

      await tester.pumpWidget(const SizedBox());

      expect(orientationRequests.last, hasLength(4));
    });

    testWidgets('shows the recording format before a take', (tester) async {
      await pumpStudio(tester);

      expect(find.text('9:16  ·  1080P  ·  30 FPS'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
