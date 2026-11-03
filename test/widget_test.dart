import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';

void main() {
  test('Script word count, markers and speaking time calculation', () {
    final script = Script(
      id: 'test_1',
      title: 'Test Script',
      content: '''[HOOK]
Welcome to the demonstration.
[TIP 1]
Here is the first important tip for speaking clearly.''',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    expect(script.wordCount, greaterThan(10));
    expect(script.markers.length, equals(2));
    expect(script.markers[0].title, equals('HOOK'));
    expect(script.markers[1].title, equals('TIP 1'));
    expect(script.estimatedReadingTimeSeconds(wordsPerMinute: 130), greaterThan(0));
  });

  test('TeleprompterSettings default values and JSON serialization', () {
    final settings = TeleprompterSettings();
    expect(settings.fontSize, equals(28.0));
    expect(settings.showGuideLine, isTrue);
    expect(settings.mirrorHorizontal, isFalse);

    final json = settings.toJson();
    final restored = TeleprompterSettings.fromJson(json);
    expect(restored.fontSize, equals(settings.fontSize));
    expect(restored.countdownDuration, equals(settings.countdownDuration));
  });
}
