import 'package:speech_to_text/speech_to_text.dart';

/// The slice of a speech recogniser that voice-follow needs.
/// Kept small so the session logic can be tested with a fake.
abstract class SpeechInput {
  /// Prepares the recogniser (and asks for permissions). False if unavailable.
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  /// Starts a listening session; [onTranscript] receives the running transcript.
  Future<void> listen({
    required void Function(String transcript) onTranscript,
    required List<String> vocabularyHints,
  });

  Future<void> stop();

  bool get isListening;
}

/// [SpeechInput] backed by the platform recogniser via `speech_to_text`.
class PlatformSpeechInput implements SpeechInput {
  static const Duration _pauseBeforeSessionEnds = Duration(seconds: 6);
  static const Duration _longestSession = Duration(minutes: 1);

  final SpeechToText _speech = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
    );
  }

  @override
  Future<void> listen({
    required void Function(String transcript) onTranscript,
    required List<String> vocabularyHints,
  }) {
    return _speech.listen(
      onResult: (result) => onTranscript(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        pauseFor: _pauseBeforeSessionEnds,
        listenFor: _longestSession,
        cancelOnError: false,
        contextualPhrases: vocabularyHints,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  bool get isListening => _speech.isListening;
}
