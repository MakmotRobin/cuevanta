import 'dart:async';
import 'package:flutter/foundation.dart';
import 'script_position_tracker.dart';
import 'speech_input.dart';

enum VoiceFollowState {
  off,
  starting,
  listening,

  /// Microphone handed to the camera while a take records (Android can't share it).
  suspended,
  unavailable,
}

/// Listens to the reader and keeps [currentWord] in step with the script.
///
/// Platform recognisers end a session after a pause or about a minute, so the
/// session restarts listening automatically until [stop] or [suspend].
class VoiceFollowSession extends ChangeNotifier {
  static const Duration _restartDelay = Duration(milliseconds: 250);
  static const int _maxVocabularyHints = 50;
  static const Set<String> _endedStatuses = {'done', 'notListening'};

  final SpeechInput _speech;
  final ScriptPositionTracker _tracker;
  final List<String> _vocabularyHints;

  VoiceFollowState _state = VoiceFollowState.off;
  String? _errorMessage;
  bool _isInitialized = false;
  Timer? _restartTimer;

  VoiceFollowSession({required String scriptContent, SpeechInput? speech})
      : _speech = speech ?? PlatformSpeechInput(),
        _tracker = ScriptPositionTracker(scriptContent),
        _vocabularyHints = distinctiveWords(scriptContent, limit: _maxVocabularyHints);

  VoiceFollowState get state => _state;
  String? get errorMessage => _errorMessage;
  ScriptWord? get currentWord => _tracker.currentWord;
  bool get isAtEnd => _tracker.isAtEnd;
  bool get isFollowing => _state == VoiceFollowState.listening || _state == VoiceFollowState.starting;

  /// Starts listening. Returns false (and becomes [VoiceFollowState.unavailable])
  /// when speech recognition can't be used on this device.
  Future<bool> start() async {
    if (isFollowing) return true;
    _setState(VoiceFollowState.starting);

    if (!_isInitialized) {
      _isInitialized = await _speech.initialize(onStatus: _handleStatus, onError: _handleError);
      if (!_isInitialized) {
        _errorMessage ??= 'Speech recognition isn\'t available on this device.';
        _setState(VoiceFollowState.unavailable);
        return false;
      }
    }
    await _listen();
    return true;
  }

  /// Releases the microphone (e.g. for camera recording) but remembers the position.
  Future<void> suspend() async {
    if (!isFollowing) return;
    _restartTimer?.cancel();
    _setState(VoiceFollowState.suspended);
    await _speech.stop();
  }

  Future<void> stop() async {
    _restartTimer?.cancel();
    _setState(VoiceFollowState.off);
    if (_speech.isListening) await _speech.stop();
  }

  /// Keeps the tracker in step after a manual jump in the prompter.
  void syncToParagraph(int paragraphIndex) {
    _tracker.moveToParagraph(paragraphIndex);
    notifyListeners();
  }

  void restartFromTop() {
    _tracker.reset();
    notifyListeners();
  }

  Future<void> _listen() async {
    await _speech.listen(onTranscript: _handleTranscript, vocabularyHints: _vocabularyHints);
    if (_state == VoiceFollowState.starting) _setState(VoiceFollowState.listening);
  }

  void _handleTranscript(String transcript) {
    if (_tracker.updateWithTranscript(transcript)) notifyListeners();
  }

  void _handleStatus(String status) {
    if (_endedStatuses.contains(status) && isFollowing) _scheduleRestart();
  }

  void _handleError(String error) {
    _errorMessage = error;
    if (isFollowing) _scheduleRestart();
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (isFollowing && !_speech.isListening) _listen();
    });
  }

  void _setState(VoiceFollowState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    if (_speech.isListening) _speech.stop();
    super.dispose();
  }

  /// Names and unusual words worth biasing the recogniser toward:
  /// anything with a capital letter after the first character of its line
  /// (ChatGPT, OpenAI, Anthropic mid-sentence) or containing digits.
  @visibleForTesting
  static List<String> distinctiveWords(String content, {required int limit}) {
    final seen = <String>{};
    final hints = <String>[];
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) continue;
      final tokens = RegExp(r"[A-Za-z0-9][A-Za-z0-9'’.-]*[A-Za-z0-9]").allMatches(trimmed).toList();
      for (var i = 0; i < tokens.length; i++) {
        final word = tokens[i].group(0)!;
        final hasInnerCapital = word.substring(1).contains(RegExp('[A-Z]'));
        final isCapitalizedMidLine = i > 0 && word[0] == word[0].toUpperCase() && RegExp('^[A-Z]').hasMatch(word);
        final hasDigit = word.contains(RegExp('[0-9]'));
        final isDistinctive = hasInnerCapital || isCapitalizedMidLine || hasDigit;
        if (isDistinctive && seen.add(word.toLowerCase())) hints.add(word);
        if (hints.length == limit) return hints;
      }
    }
    return hints;
  }
}
