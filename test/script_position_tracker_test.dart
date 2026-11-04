import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/voice/script_position_tracker.dart';

const String _script = '[HOOK]\n'
    'Everyone is talking about AI agents, so let me explain them in 2 minutes.\n'
    'A normal chatbot answers you.\n'
    'An agent does things for you.\n'
    'Anthropic made sixteen billion dollars in six months.\n'
    'And if you need help with anything tech, check out unibruz dot com.';

String _wordAt(ScriptPositionTracker tracker) => tracker.currentWord!.normalized;

void main() {
  group('ScriptPositionTracker', () {
    late ScriptPositionTracker tracker;

    setUp(() => tracker = ScriptPositionTracker(_script));

    test('starts before the first word', () {
      expect(tracker.currentIndex, -1);
      expect(tracker.currentWord, isNull);
    });

    test('marker lines are not spoken words', () {
      expect(tracker.words.first.normalized, 'everyone');
      expect(tracker.words.first.paragraphIndex, 1);
    });

    test('records where each word starts in its line', () {
      final agents = tracker.words.firstWhere((w) => w.normalized == 'agents');

      expect(agents.charOffset, _script.split('\n')[1].indexOf('agents'));
    });

    test('follows the reader through the opening words', () {
      tracker.updateWithTranscript('everyone is talking about');

      expect(_wordAt(tracker), 'about');
    });

    test('follows partial results as a sentence grows', () {
      tracker.updateWithTranscript('everyone is talking');
      tracker.updateWithTranscript('everyone is talking about AI agents so let me');

      expect(_wordAt(tracker), 'me');
      expect(tracker.currentWord!.paragraphIndex, 1);
    });

    test('repeating the same partial result does not move again', () {
      tracker.updateWithTranscript('everyone is talking about');

      expect(tracker.updateWithTranscript('everyone is talking about'), isFalse);
    });

    test('spoken numbers match digits in the script', () {
      tracker.updateWithTranscript('everyone is talking about AI agents so let me');
      tracker.updateWithTranscript('let me explain them in two minutes');

      expect(_wordAt(tracker), 'minutes');
    });

    test('a one-letter recognition slip in a long word still matches', () {
      tracker.updateWithTranscript('an agent does things for you');
      tracker.updateWithTranscript('anthropik made sixteen billion');

      expect(_wordAt(tracker), 'billion');
    });

    test('skipping ahead a line is picked up within the look-ahead', () {
      tracker.updateWithTranscript('everyone is talking about AI agents');
      tracker.updateWithTranscript('a normal chatbot answers you an agent does things');

      expect(tracker.currentWord!.paragraphIndex, 3);
    });

    test('common words alone never move the position', () {
      tracker.updateWithTranscript('everyone is talking about');
      final before = tracker.currentIndex;

      tracker.updateWithTranscript('and the');

      expect(tracker.currentIndex, before);
    });

    test('unrelated speech does not move the position', () {
      tracker.updateWithTranscript('everyone is talking about');
      final before = tracker.currentIndex;

      tracker.updateWithTranscript('hold on let me grab some water');

      expect(tracker.currentIndex, before);
    });

    test('a single heard word only confirms the next word or two', () {
      tracker.updateWithTranscript('everyone is talking about');

      expect(tracker.updateWithTranscript('chatbot'), isFalse);
      expect(tracker.updateWithTranscript('AI'), isTrue);
      expect(_wordAt(tracker), 'ai');
    });

    test('re-reading a line with a strong match moves back to it', () {
      tracker.updateWithTranscript('a normal chatbot answers you');
      tracker.updateWithTranscript('an agent does things for you');

      tracker.updateWithTranscript('a normal chatbot answers');

      expect(_wordAt(tracker), 'answers');
    });

    test('a weak match never drags the position backwards', () {
      tracker.updateWithTranscript('a normal chatbot answers you');
      tracker.updateWithTranscript('an agent does things for you');
      final before = tracker.currentIndex;

      tracker.updateWithTranscript('chatbot answers');

      expect(tracker.currentIndex, before);
    });

    test('reaching the last words reports the end', () {
      tracker.moveToParagraph(5);
      tracker.updateWithTranscript('check out unibruz dot com');

      expect(tracker.isAtEnd, isTrue);
    });

    test('moving to a line puts the position just before its first word', () {
      tracker.moveToParagraph(4);

      expect(tracker.words[tracker.currentIndex + 1].normalized, 'anthropic');
    });

    test('reset returns to before the first word', () {
      tracker.updateWithTranscript('everyone is talking about');
      tracker.reset();

      expect(tracker.currentIndex, -1);
    });

    test('reading the whole script with restarting recogniser sessions reaches the end', () {
      const wordsPerSession = 7;
      final spoken = ScriptPositionTracker.normalizeWords(_script.replaceAll('[HOOK]', ''));

      for (var start = 0; start < spoken.length; start += wordsPerSession) {
        final session = <String>[];
        for (final word in spoken.skip(start).take(wordsPerSession)) {
          session.add(word);
          tracker.updateWithTranscript(session.join(' '));
        }
      }

      expect(tracker.isAtEnd, isTrue);
    });

    test('normalizeWords lowercases, strips punctuation and writes numbers as digits', () {
      expect(
        ScriptPositionTracker.normalizeWords("Haven't seen TWO agents, okay?"),
        ['havent', 'seen', '2', 'agents', 'okay'],
      );
    });
  });
}
