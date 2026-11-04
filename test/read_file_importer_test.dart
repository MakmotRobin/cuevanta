import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/import/read_file_importer.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/services/storage_service.dart';

const String _week = '''# READ — Week of Wednesday 4 November 2026

## 1 · WED · AM · FIRST TOPIC

First line.

*Backup opening lines:*
*— Hook one.*

---

## 2 · WED · PM · SECOND TOPIC

Second script.
''';

Future<List<Script>> _importedScripts(StorageService storage) async =>
    (await storage.getScripts()).where((s) => s.id.startsWith('read-')).toList();

void main() {
  late StorageService storage;
  late ReadFileImporter importer;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.saveScripts([]);
    importer = ReadFileImporter(storage: storage);
  });

  group('ReadFileImporter', () {
    test('first import adds every section as a new script', () async {
      final summary = await importer.importMarkdown(_week, sourceName: 'week.md');

      expect(summary.added, 2);
      expect(summary.updated, 0);
      expect(await _importedScripts(storage), hasLength(2));
    });

    test('re-importing the same file updates scripts instead of duplicating them', () async {
      await importer.importMarkdown(_week, sourceName: 'week.md');
      final summary = await importer.importMarkdown(
        _week.replaceFirst('First line.', 'Rewritten first line.'),
        sourceName: 'week.md',
      );

      final scripts = await _importedScripts(storage);
      expect(summary.updated, 2);
      expect(scripts, hasLength(2));
      expect(scripts.any((s) => s.content == 'Rewritten first line.'), isTrue);
    });

    test('re-importing keeps per-script prompter tweaks', () async {
      await importer.importMarkdown(_week, sourceName: 'week.md');
      final first = (await _importedScripts(storage)).first;
      await storage.addOrUpdateScript(first.copyWith(customSpeed: 55));

      await importer.importMarkdown(_week, sourceName: 'week.md');

      final reimported = (await _importedScripts(storage)).firstWhere((s) => s.id == first.id);
      expect(reimported.customSpeed, 55);
    });

    test('imported scripts list in file order when sorted newest first', () async {
      await importer.importMarkdown(_week, sourceName: 'week.md');

      final scripts = await _importedScripts(storage)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      expect(scripts.map((s) => s.title), ['01 · WED AM · First topic', '02 · WED PM · Second topic']);
    });

    test('a file without script sections is rejected', () async {
      expect(
        () => importer.importMarkdown('# Just a title\n\nSome notes.', sourceName: 'notes.md'),
        throwsFormatException,
      );
    });
  });

  group('Script.withOpeningSwapped', () {
    final script = Script(
      id: 'x',
      title: 'x',
      content: '[HOOK]\nOriginal opening.\nSecond line.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      backupOpenings: ['Backup A.', 'Backup B.'],
    );

    test('replaces the first spoken line, skipping markers', () {
      expect(script.withOpeningSwapped(1).content, '[HOOK]\nBackup B.\nSecond line.');
    });

    test('moves the replaced line into the backup slot', () {
      expect(script.withOpeningSwapped(1).backupOpenings, ['Backup A.', 'Original opening.']);
    });

    test('swapping the same slot twice restores the original', () {
      final restored = script.withOpeningSwapped(0).withOpeningSwapped(0);

      expect(restored.content, script.content);
      expect(restored.backupOpenings, script.backupOpenings);
    });

    test('an out-of-range index leaves the script unchanged', () {
      expect(script.withOpeningSwapped(5).content, script.content);
    });

    test('backup openings survive a save and load round trip', () {
      expect(Script.fromJson(script.toJson()).backupOpenings, script.backupOpenings);
    });
  });
}
