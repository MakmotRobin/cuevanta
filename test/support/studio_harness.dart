import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/screens/studio_recording_screen.dart';

/// Opens the recording studio for [script] and lets its (camera-less) start-up finish.
///
/// [onOrientationRequest] receives each SystemChrome orientation request.
Future<void> openStudio(
  WidgetTester tester,
  Script script, {
  void Function(Object? orientations)? onOrientationRequest,
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') onOrientationRequest?.call(call.arguments);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StudioRecordingScreen(script: script)),
        ),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
  await _waitUntilCameraStartupEnds(tester);
}

/// Camera start-up resolves on real async I/O, which the fake clock doesn't advance,
/// so give it real time until the loading view is gone.
Future<void> _waitUntilCameraStartupEnds(WidgetTester tester) async {
  const maxAttempts = 40;
  final studio = find.byType(StudioRecordingScreen);
  final loadingView = find.text('Starting camera…');
  bool isStillStarting() => studio.evaluate().isEmpty || loadingView.evaluate().isNotEmpty;

  for (var attempt = 0; attempt < maxAttempts && isStillStarting(); attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  expect(isStillStarting(), isFalse, reason: 'studio never finished starting');
  await tester.pump(const Duration(milliseconds: 400)); // page transition
}
