import 'package:shared_preferences/shared_preferences.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../models/recorded_video.dart';

class StorageService {
  static const String _keyScripts = 'teleprompter_scripts_v1';
  static const String _keySettings = 'teleprompter_settings_v1';
  static const String _keyRecordings = 'teleprompter_recordings_v1';

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all scripts, seeding defaults if empty
  Future<List<Script>> getScripts() async {
    await init();
    final rawList = _prefs?.getStringList(_keyScripts);
    if (rawList == null || rawList.isEmpty) {
      final defaults = _getDefaultScripts();
      await saveScripts(defaults);
      return defaults;
    }
    try {
      return rawList.map((str) => Script.fromJson(str)).toList();
    } catch (_) {
      return _getDefaultScripts();
    }
  }

  Future<void> saveScripts(List<Script> scripts) async {
    await init();
    final jsonList = scripts.map((s) => s.toJson()).toList();
    await _prefs?.setStringList(_keyScripts, jsonList);
  }

  Future<void> addOrUpdateScript(Script script) async {
    final scripts = await getScripts();
    final index = scripts.indexWhere((s) => s.id == script.id);
    if (index >= 0) {
      scripts[index] = script.copyWith(updatedAt: DateTime.now());
    } else {
      scripts.insert(0, script);
    }
    await saveScripts(scripts);
  }

  Future<void> deleteScript(String id) async {
    final scripts = await getScripts();
    scripts.removeWhere((s) => s.id == id);
    await saveScripts(scripts);
  }

  Future<Script?> getScript(String id) async {
    final scripts = await getScripts();
    try {
      return scripts.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Load settings
  Future<TeleprompterSettings> getSettings() async {
    await init();
    final jsonStr = _prefs?.getString(_keySettings);
    if (jsonStr != null) {
      try {
        return TeleprompterSettings.fromJson(jsonStr);
      } catch (_) {
        return TeleprompterSettings();
      }
    }
    return TeleprompterSettings();
  }

  Future<void> saveSettings(TeleprompterSettings settings) async {
    await init();
    await _prefs?.setString(_keySettings, settings.toJson());
  }

  /// Recordings history
  Future<List<RecordedVideo>> getRecordings() async {
    await init();
    final rawList = _prefs?.getStringList(_keyRecordings);
    if (rawList == null) return [];
    try {
      return rawList.map((str) => RecordedVideo.fromJson(str)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecording(RecordedVideo video) async {
    final list = await getRecordings();
    list.insert(0, video);
    await init();
    await _prefs?.setStringList(_keyRecordings, list.map((v) => v.toJson()).toList());
  }

  Future<void> deleteRecording(String id) async {
    final list = await getRecordings();
    list.removeWhere((v) => v.id == id);
    await init();
    await _prefs?.setStringList(_keyRecordings, list.map((v) => v.toJson()).toList());
  }

  List<Script> _getDefaultScripts() {
    final now = DateTime.now();
    return [
      Script(
        id: 'default_1',
        title: 'YouTube Video: 5 Tips for Better Video Presentations',
        content: '''[INTRO - THE HOOK]
Hey everyone, welcome back to the channel!
Today, I'm going to share 5 game-changing techniques to look confident, maintain natural eye contact, and never lose your train of thought on camera.

[TIP 1 - EYE CONTACT]
The biggest mistake people make when reading a script is looking down away from the lens.
With this teleprompter, place the text right below the camera lens at the top of your screen. That way, you maintain direct, warm connection with your viewer.

[TIP 2 - PACING AND BREATHING]
Don't rush! Speak naturally, just like having a coffee conversation with a good friend.
Notice punctuation marks as your cue to breathe. Pauses create suspense and authority.

[TIP 3 - VOCAL ENERGY]
Smiling before you start speaking automatically brightens your voice tone.
Engage your hands and let your natural body language accentuate your points.

[TIP 4 - FORMATTING YOUR SCRIPT]
Use bracketed cues like [INTRO] or [KEY POINT] to break down your script into digestible sections. You can easily jump directly to them anytime.

[CALL TO ACTION]
If you found these tips helpful, smash that like button, subscribe for more content, and let me know in the comments: what video are you recording today?

Thanks for watching, and see you in the next one!''',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Script(
        id: 'default_2',
        title: '60-Second Short: How to Master Any Skill',
        content: '''[HOOK]
What if I told you the 10,000-hour rule is wrong? Here is how you can actually master any new skill in just 20 hours.

[THE SCIENCE]
Author Josh Kaufman found that going from zero to reasonably proficient only takes approximately 20 hours of focused deliberate practice. That's just 45 minutes a day for one month!

[THE 3 STEPS]
Step 1: Deconstruct the skill into tiny sub-components.
Step 2: Learn just enough to self-correct and identify mistakes.
Step 3: Remove emotional barriers like fear of looking silly.

[OUTRO]
Pick that one skill you have been putting off, start your 20 hours today, and follow for more daily productivity insights!''',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      Script(
        id: 'default_3',
        title: 'Executive Pitch: Product Launch Briefing',
        content: '''[WELCOME]
Good morning, executive board members and valued partners.
I am thrilled to present our vision for the next quarter.

[THE PROBLEM]
Over 78% of remote communicators report camera fatigue and struggle with natural delivery when presenting key updates to clients.

[OUR SOLUTION]
We engineered a seamless, studio-grade teleprompter experience designed for creators, leaders, and educators.
It keeps eye contact locked right on target, synchronizes scrolling speeds to natural human speech, and enables one-tap recording directly from your phone.

[THE IMPACT]
Pilot users experienced a 40% reduction in production time and recorded 3x more video updates per week.

[CLOSING]
Thank you for your time, and I welcome any questions.''',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
