import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../services/storage_service.dart';
import 'voice_follow_session.dart';

/// Shared voice-follow lifecycle for screens that show a prompter.
///
/// The session exists only while the "Follow my voice" setting is on, and the
/// screen rebuilds when its listening state changes (not on every word).
mixin VoiceFollowHost<T extends StatefulWidget> on State<T> {
  VoiceFollowSession? voiceFollow;
  VoiceFollowState? _lastReportedState;

  /// Creates the session when the setting is on, without starting to listen yet.
  void prepareVoiceFollow(Script script, TeleprompterSettings settings) {
    if (!settings.followVoice || voiceFollow != null) return;
    voiceFollow = VoiceFollowSession(scriptContent: script.content)
      ..addListener(_rebuildOnStateChange);
  }

  /// Line on the prompter's reading guide, so following starts from where the reader is.
  int currentParagraphAtGuide();

  /// Starts listening; turns the setting back off if recognition is unavailable.
  Future<void> startVoiceFollow(TeleprompterSettings settings) async {
    final session = voiceFollow;
    if (session == null) return;
    session.syncToParagraph(currentParagraphAtGuide());
    if (await session.start()) return;

    settings.followVoice = false;
    StorageService().saveSettings(settings);
    _showUnavailableMessage(session.errorMessage);
    disposeVoiceFollow();
  }

  /// HUD mic button: flips the setting, saves it, and starts or stops listening.
  Future<void> toggleVoiceFollow(Script script, TeleprompterSettings settings) async {
    settings.followVoice = !settings.followVoice;
    StorageService().saveSettings(settings);
    await applyVoiceFollowSetting(script, settings);
  }

  /// Brings the session in line with [settings] after any settings change.
  Future<void> applyVoiceFollowSetting(Script script, TeleprompterSettings settings) async {
    if (settings.followVoice && voiceFollow == null) {
      prepareVoiceFollow(script, settings);
      await startVoiceFollow(settings);
    } else if (!settings.followVoice && voiceFollow != null) {
      disposeVoiceFollow();
    }
    if (mounted) setState(() {});
  }

  void disposeVoiceFollow() {
    final session = voiceFollow;
    voiceFollow = null;
    _lastReportedState = null;
    if (session == null) return;
    session.removeListener(_rebuildOnStateChange);
    session.stop();
    session.dispose();
  }

  void _rebuildOnStateChange() {
    final state = voiceFollow?.state;
    if (state == _lastReportedState || !mounted) return;
    _lastReportedState = state;
    setState(() {});
  }

  void _showUnavailableMessage(String? reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Voice follow is off: ${reason ?? 'speech recognition is unavailable'}.'),
      ));
  }
}
