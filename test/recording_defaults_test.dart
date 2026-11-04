import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/services/recording_format.dart';
import 'package:teleprompter/services/storage_service.dart';
import 'support/studio_harness.dart';

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

    Future<void> pumpStudio(WidgetTester tester) =>
        openStudio(tester, _script, onOrientationRequest: orientationRequests.add);

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
