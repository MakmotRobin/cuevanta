import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/services/storage_service.dart';
import 'support/studio_harness.dart';

final Script _script = Script(
  id: 'studio',
  title: 'Studio',
  content: 'A short line to read.',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Shown when the studio tries to record on a machine without a camera.
final Finder _recordingAttempt = find.textContaining('Not recording');

Future<void> _openStudioWith(WidgetTester tester, TeleprompterSettings settings) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.resetForTesting();
  await storage.saveSettings(settings);
  await openStudio(tester, _script);
}

void main() {
  testWidgets('opening the studio counts down and then tries to record', (tester) async {
    await _openStudioWith(tester, TeleprompterSettings(countdownDuration: 3));
    expect(find.text('Recording starts…  tap to skip'), findsOneWidget);
    expect(_recordingAttempt, findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(_recordingAttempt, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with auto-record off, the opening countdown only starts scrolling', (tester) async {
    await _openStudioWith(tester, TeleprompterSettings(countdownDuration: 3, autoRecordVideo: false));
    expect(find.text('Get ready…  tap to skip'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(_recordingAttempt, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the shutter counts down before recording', (tester) async {
    await _openStudioWith(tester, TeleprompterSettings(countdownDuration: 3, autoRecordVideo: false));
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byTooltip('Start recording'));
    await tester.pump();
    expect(find.text('Recording starts…  tap to skip'), findsOneWidget);
    expect(_recordingAttempt, findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(_recordingAttempt, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
