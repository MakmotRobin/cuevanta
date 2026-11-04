import '../models/script.dart';
import '../services/storage_service.dart';
import 'read_file_parser.dart';

class ReadImportSummary {
  final int added;
  final int updated;

  const ReadImportSummary({required this.added, required this.updated});

  int get total => added + updated;
}

/// Turns a weekly READ file into scripts, updating ones imported before.
class ReadFileImporter {
  final ReadFileParser _parser;
  final StorageService _storage;

  ReadFileImporter({ReadFileParser? parser, StorageService? storage})
      : _parser = parser ?? ReadFileParser(),
        _storage = storage ?? StorageService();

  /// Throws [FormatException] when the file contains no script sections.
  Future<ReadImportSummary> importMarkdown(String markdown, {required String sourceName}) async {
    final parsed = _parser.parse(markdown, sourceName: sourceName);
    if (parsed.isEmpty) {
      throw const FormatException('No "## " script sections found in this file.');
    }

    final scripts = await _storage.getScripts();
    final indexById = {for (var i = 0; i < scripts.length; i++) scripts[i].id: i};
    final importTime = DateTime.now();
    var added = 0;

    for (var i = 0; i < parsed.length; i++) {
      // Earlier sections get later timestamps so the newest-first list keeps file order.
      final orderedTime = importTime.subtract(Duration(milliseconds: i));
      final existingIndex = indexById[parsed[i].id];
      if (existingIndex == null) {
        scripts.add(_newScript(parsed[i], orderedTime));
        added++;
      } else {
        scripts[existingIndex] = _refreshedScript(scripts[existingIndex], parsed[i], orderedTime);
      }
    }

    await _storage.saveScripts(scripts);
    return ReadImportSummary(added: added, updated: parsed.length - added);
  }

  Script _newScript(ParsedReadScript parsed, DateTime timestamp) => Script(
        id: parsed.id,
        title: parsed.title,
        content: parsed.content,
        createdAt: timestamp,
        updatedAt: timestamp,
        backupOpenings: List.of(parsed.backupOpenings),
      );

  /// Keeps per-script prompter tweaks (speed, font size, notes) from the earlier import.
  Script _refreshedScript(Script existing, ParsedReadScript parsed, DateTime timestamp) =>
      existing.copyWith(
        title: parsed.title,
        content: parsed.content,
        backupOpenings: List.of(parsed.backupOpenings),
        updatedAt: timestamp,
      );
}
