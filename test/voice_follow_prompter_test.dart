import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/voice/voice_follow_session.dart';
import 'package:teleprompter/widgets/prompter_view.dart';
import 'support/fake_speech_input.dart';

final Script _script = Script(
  id: 'voice',
  title: 'Voice',
  content: [
    for (var i = 1; i <= 30; i++) 'Line number $i talks about topic$i in plain words.',
  ].join('\n'),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

double _scrollOffset(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

Future<void> _runFrames(WidgetTester tester, Duration duration) async {
  const frame = Duration(milliseconds: 16);
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
    await tester.pump(frame);
  }
}

void main() {
  late FakeSpeechInput speech;
  late VoiceFollowSession session;

  setUp(() async {
    speech = FakeSpeechInput();
    session = VoiceFollowSession(scriptContent: _script.content, speech: speech);
    await session.start();
  });

  tearDown(() => session.dispose());

  Future<void> pumpPrompter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PrompterView(
          script: _script,
          settings: TeleprompterSettings(countdownDuration: 0),
          voiceFollow: session,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('scrolls toward the line being spoken', (tester) async {
    await pumpPrompter(tester);

    session.syncToParagraph(11);
    speech.say('line number 12 talks about topic12 in plain');
    await _runFrames(tester, const Duration(seconds: 2));

    expect(_scrollOffset(tester), greaterThan(200));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('holds still while the reader is silent', (tester) async {
    await pumpPrompter(tester);

    await _runFrames(tester, const Duration(seconds: 3));

    expect(_scrollOffset(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stops moving once it reaches the spoken line', (tester) async {
    await pumpPrompter(tester);
    session.syncToParagraph(5);
    speech.say('line number 6 talks about topic6 in plain');
    await _runFrames(tester, const Duration(seconds: 3));
    final settled = _scrollOffset(tester);

    await _runFrames(tester, const Duration(seconds: 2));

    expect(_scrollOffset(tester), closeTo(settled, 0.5));
    await tester.pumpWidget(const SizedBox());
  });
}
