import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/import/read_file_parser.dart';

/// Excerpt in the exact shape of the weekly READ files.
const String _weekFile = '''# READ — Week of Wednesday 4 November 2026

Only the words you say. One sentence per line. Read it straight down.

---

## 1 · WED · AM · CHATGPT IS MERGING CHAT AND WORK

ChatGPT is about to look different, and most people haven't noticed yet.

OpenAI has emailed users to say it's merging chat and work into one.

And if you need help with anything tech, check out unibruz dot com.

*Backup opening lines:*
*— Your ChatGPT app is about to change. Here's what's coming.*
*— OpenAI just told users ChatGPT is getting rebuilt around one idea.*

---

## 2 · WED · PM · LEARN AI AGENTS IN 2 MINUTES

Everyone's talking about AI agents, so let me explain them in two minutes.

And if you need help with anything tech, check out unibruz dot com.

---

# SPARE SCRIPTS

---

## S1 · SPARE · GTA 6 IS ALMOST HERE, BUT NOT FOR PC

GTA six is weeks away, and PC players have to wait.

And if you need help with anything tech, check out unibruz dot com.

*Backup opening lines:*
*— GTA six is weeks away. PC players, I've got bad news.*
''';

List<ParsedReadScript> _parse(String markdown, {String sourceName = 'week.md'}) =>
    ReadFileParser().parse(markdown, sourceName: sourceName);

void main() {
  group('ReadFileParser', () {
    test('creates one script per section and skips the title and intro', () {
      final scripts = _parse(_weekFile);

      expect(scripts, hasLength(3));
      expect(scripts.any((s) => s.content.contains('Only the words you say')), isFalse);
    });

    test('titles combine padded number, day and slot, and the topic in sentence case', () {
      expect(_parse(_weekFile).first.title, '01 · WED AM · ChatGPT is merging chat and work');
    });

    test('keeps acronyms from the script body in the title', () {
      expect(_parse(_weekFile)[1].title, '02 · WED PM · Learn AI agents in 2 minutes');
    });

    test('content is one spoken sentence per line with no markdown or separators', () {
      expect(
        _parse(_weekFile).first.content,
        "ChatGPT is about to look different, and most people haven't noticed yet.\n"
        "OpenAI has emailed users to say it's merging chat and work into one.\n"
        'And if you need help with anything tech, check out unibruz dot com.',
      );
    });

    test('backup opening lines are kept out of the content', () {
      final first = _parse(_weekFile).first;

      expect(first.content, isNot(contains('Backup')));
      expect(first.content, isNot(contains('rebuilt around one idea')));
    });

    test('backup opening lines are stored without italics or dash', () {
      expect(_parse(_weekFile).first.backupOpenings, [
        "Your ChatGPT app is about to change. Here's what's coming.",
        'OpenAI just told users ChatGPT is getting rebuilt around one idea.',
      ]);
    });

    test('a section without backup lines has no backup openings', () {
      expect(_parse(_weekFile)[1].backupOpenings, isEmpty);
    });

    test('spare sections after "# SPARE SCRIPTS" are imported with their own label', () {
      final spare = _parse(_weekFile).last;

      expect(spare.title, 'S1 · SPARE · GTA 6 is almost here, but not for PC');
      expect(spare.backupOpenings, ["GTA six is weeks away. PC players, I've got bad news."]);
    });

    test('CRLF line endings parse the same as LF', () {
      final lf = _parse(_weekFile);
      final crlf = _parse(_weekFile.replaceAll('\n', '\r\n'));

      expect(crlf.map((s) => s.content), lf.map((s) => s.content));
      expect(crlf.map((s) => s.backupOpenings), lf.map((s) => s.backupOpenings));
    });

    test('ids are stable when the same file is parsed again', () {
      expect(_parse(_weekFile).map((s) => s.id), _parse(_weekFile).map((s) => s.id));
    });

    test('ids are unique within a week and differ between weeks', () {
      final thisWeek = _parse(_weekFile).map((s) => s.id).toSet();
      final nextWeek = _parse(_weekFile.replaceFirst('4 November', '11 November')).map((s) => s.id);

      expect(thisWeek, hasLength(3));
      expect(thisWeek.intersection(nextWeek.toSet()), isEmpty);
    });

    test('headings without day and slot keep just number and topic', () {
      const daily = '# READ — Tuesday 3 November 2026\n\n## 1 · INTRO\n\nI am Robin.\n';

      expect(_parse(daily).single.title, '01 · Intro');
    });

    test('a file without a title line uses the source name to identify the week', () {
      const untitled = '## 1 · HELLO\n\nHello there.\n';

      expect(_parse(untitled, sourceName: 'week-a.md').single.id,
          isNot(_parse(untitled, sourceName: 'week-b.md').single.id));
    });

    test('bold, italics and escaped characters are stripped from spoken lines', () {
      const styled = '## 1 · STYLE\n\nThis is **really** _simple_ \\*honestly\\*.\n';

      expect(_parse(styled).single.content, 'This is really simple *honestly*.');
    });

    test('a section with only backup lines is skipped', () {
      const empty = '## 1 · EMPTY\n\n*Backup opening lines:*\n*— Only a hook.*\n';

      expect(_parse(empty), isEmpty);
    });
  });
}
