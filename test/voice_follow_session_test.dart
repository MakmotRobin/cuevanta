import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/voice/voice_follow_session.dart';
import 'support/fake_speech_input.dart';

const String _script = 'Everyone is talking about AI agents.\nOpenAI and Anthropic ship new models in 2026.';

void main() {
  late FakeSpeechInput speech;
  late VoiceFollowSession session;

  setUp(() {
    speech = FakeSpeechInput();
    session = VoiceFollowSession(scriptContent: _script, speech: speech);
  });

  tearDown(() => session.dispose());

  test('starting begins listening', () async {
    expect(await session.start(), isTrue);

    expect(session.state, VoiceFollowState.listening);
    expect(speech.listenCount, 1);
  });

  test('an unavailable recogniser leaves the session unavailable', () async {
    speech.isAvailable = false;

    expect(await session.start(), isFalse);
    expect(session.state, VoiceFollowState.unavailable);
    expect(session.errorMessage, isNotNull);
  });

  test('heard words move the current word and notify listeners', () async {
    await session.start();
    var notified = false;
    session.addListener(() => notified = true);

    speech.say('everyone is talking about');

    expect(session.currentWord!.normalized, 'about');
    expect(notified, isTrue);
  });

  test('listening restarts by itself when the platform ends a session', () {
    fakeAsync((async) {
      session.start();
      async.flushMicrotasks();

      speech.endSession();
      async.elapse(const Duration(seconds: 1));

      expect(speech.listenCount, 2);
    });
  });

  test('suspending releases the microphone and stops restarts', () {
    fakeAsync((async) {
      session.start();
      async.flushMicrotasks();

      session.suspend();
      async.flushMicrotasks();
      speech.endSession();
      async.elapse(const Duration(seconds: 1));

      expect(session.state, VoiceFollowState.suspended);
      expect(speech.stopCount, 1);
      expect(speech.listenCount, 1);
    });
  });

  test('starting again after suspending listens from the same place', () async {
    await session.start();
    speech.say('everyone is talking about');
    await session.suspend();

    await session.start();

    expect(session.state, VoiceFollowState.listening);
    expect(session.currentWord!.normalized, 'about');
  });

  test('stopping turns the session off', () async {
    await session.start();

    await session.stop();

    expect(session.state, VoiceFollowState.off);
    expect(speech.isListening, isFalse);
  });

  test('the recogniser is hinted with names and numbers from the script', () async {
    await session.start();

    expect(speech.lastHints, containsAll(['AI', 'OpenAI', 'Anthropic', '2026']));
    expect(speech.lastHints, isNot(contains('Everyone')));
  });
}
