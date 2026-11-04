import 'package:teleprompter/voice/speech_input.dart';

/// Scriptable stand-in for the platform speech recogniser.
class FakeSpeechInput implements SpeechInput {
  bool isAvailable = true;
  int listenCount = 0;
  int stopCount = 0;
  List<String> lastHints = [];
  late void Function(String status) emitStatus;
  late void Function(String error) emitError;
  void Function(String transcript)? _onTranscript;
  bool _listening = false;

  void say(String transcript) => _onTranscript?.call(transcript);

  /// Simulates the platform ending a session after a pause.
  void endSession() {
    _listening = false;
    emitStatus('done');
  }

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    emitStatus = onStatus;
    emitError = onError;
    return isAvailable;
  }

  @override
  Future<void> listen({
    required void Function(String transcript) onTranscript,
    required List<String> vocabularyHints,
  }) async {
    listenCount++;
    lastHints = vocabularyHints;
    _onTranscript = onTranscript;
    _listening = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _listening = false;
  }

  @override
  bool get isListening => _listening;
}
