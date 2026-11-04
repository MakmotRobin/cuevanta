import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/widgets/prompter_view.dart';

final Script _script = Script(
  id: 'end',
  title: 'End',
  content: [for (var i = 1; i <= 12; i++) 'Spoken line $i.', '', '[OUTRO]'].join('\n'),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

double _scrollOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

double _maxScroll(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent;

Future<void> _runFrames(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
    await tester.pump(frame);
  }
}

/// At top speed, comfortably longer than it takes the 12 lines to pass the guide.
const Duration _longEnoughToReachTheEnd = Duration(seconds: 12);

void main() {
  late int scriptEndCalls;
  late double offsetAtScriptEnd;
  late PrompterViewController controller;
  late int countdownFinishedCalls;

  Future<void> pumpPrompter(WidgetTester tester, {int countdown = 0, double speed = 150}) async {
    scriptEndCalls = 0;
    countdownFinishedCalls = 0;
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => PrompterView(
            script: _script,
            settings: TeleprompterSettings(countdownDuration: countdown, scrollSpeed: speed),
            onControllerReady: (c) => controller = c,
            onCountdownFinished: () => countdownFinishedCalls++,
            onScriptEnd: () {
              scriptEndCalls++;
              offsetAtScriptEnd = _scrollOffset(tester);
            },
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('End of script', () {
    testWidgets('is reported once the last spoken line passes the guide', (tester) async {
      await pumpPrompter(tester);

      await _runFrames(tester, _longEnoughToReachTheEnd);

      expect(scriptEndCalls, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ignores trailing blank lines and markers after the last spoken line', (tester) async {
      await pumpPrompter(tester);

      await _runFrames(tester, _longEnoughToReachTheEnd);

      // The blank line and [OUTRO] marker below the last spoken line are ~80px tall.
      expect(offsetAtScriptEnd, lessThan(_maxScroll(tester) - 50));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is not reported while lines are still to come', (tester) async {
      await pumpPrompter(tester, speed: 20);

      await _runFrames(tester, const Duration(seconds: 2));

      expect(scriptEndCalls, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('is reported again after restarting from the top', (tester) async {
      await pumpPrompter(tester);
      await _runFrames(tester, _longEnoughToReachTheEnd);

      controller.restart();
      controller.play();
      await _runFrames(tester, _longEnoughToReachTheEnd);

      expect(scriptEndCalls, 2);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Countdown on demand', () {
    testWidgets('counts down from the configured number, then reports and plays', (tester) async {
      await pumpPrompter(tester, countdown: 3);
      await tester.pump(const Duration(seconds: 4));
      controller.pause();
      final finishedBefore = countdownFinishedCalls;

      controller.startCountdown();
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(countdownFinishedCalls, finishedBefore + 1);
      expect(controller.isPlaying(), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with the countdown off, starts straight away', (tester) async {
      await pumpPrompter(tester);
      controller.pause();
      final finishedBefore = countdownFinishedCalls;

      controller.startCountdown();
      await tester.pump();

      expect(countdownFinishedCalls, finishedBefore + 1);
      expect(controller.isPlaying(), isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Take settings', () {
    test('stopping at the end of the script is on by default', () {
      expect(TeleprompterSettings().autoStopAtEnd, isTrue);
    });

    test('the auto-stop choice survives a save and load', () {
      final restored = TeleprompterSettings.fromJson(TeleprompterSettings(autoStopAtEnd: false).toJson());

      expect(restored.autoStopAtEnd, isFalse);
    });
  });
}
