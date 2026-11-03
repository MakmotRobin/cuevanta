# Teleprompter Studio (Flutter Mobile App)

A studio-grade teleprompter mobile app built with Flutter, designed specifically for content creators, presenters, educators, and vloggers who need to read scripts seamlessly while recording video on camera.

Inspired by industry references [Imaginary-Teleprompter](https://github.com/ImaginarySense/Imaginary-Teleprompter.git) and [QPrompt-Teleprompter](https://github.com/Cuperino/QPrompt-Teleprompter.git).

---

## Key Features

### 1. Dual Teleprompter Modes
- **Video Studio Mode (Read & Record on Phone)**:
  - Superimposes the scrolling script directly over the live front or rear camera preview.
  - **Camera Eye-Contact Alignment**: Positions script text right under the phone's front camera lens with customizable horizontal eye margins, ensuring direct, natural eye contact with the audience without looking like you are reading.
  - Synchronized start: Countdown timer (3..2..1) starts video recording and prompter scrolling simultaneously.
  - In-studio controls: Toggle front/rear camera, adjust background opacity, and review takes immediately upon stopping.
- **Standalone Prompter Mode (Glass Rig / Beam-Splitter)**:
  - Fullscreen prompter for use with dedicated camera rigs, teleprompter glass hoods, or tablets.
  - **Mirror Horizontal (Flip X)** & **Mirror Vertical (Flip Y)** for reflection optics.
  - Distraction-free auto-fading HUD controls.

### 2. Frame-Synchronized Smooth Scrolling Engine
- Linear, sub-pixel microsecond-precise `Ticker` scroll engine without the jarring velocity jumps of standard animations.
- Dynamic speed adjustment on the fly (`+` / `-` buttons, slider, or keyboard shortcuts).
- Tap anywhere to pause and resume instantly.
- Bluetooth clicker & hardware keyboard shortcuts:
  - **Spacebar**: Play / Pause
  - **Up / Down arrows**: Increase / Decrease scroll speed
  - **Home**: Restart to top

### 3. Eye-Level Reading Focus Guide
- Visual guide bar or reading line at the presenter's exact eye level.
- Three guide modes:
  - **Highlight Band**: Illuminates the current reading line.
  - **Guide Line with Margin Arrows**: Left and right chevrons marking the focus zone.
  - **Dimmed Edges**: Keeps focus centered while dimming text above and below.

### 4. Smart Script Management & Marker Cues
- Live word count, character count, and speech duration calculator (based on standard speaking rate of ~130 WPM).
- **Bracket Cue Navigation**: Use markers like `[HOOK]`, `[INTRO]`, `[TIP 1]`, `[CALL TO ACTION]` to structure scripts.
- Instant jump menu during prompting to jump directly to any cue marker.
- Pre-loaded templates:
  - *YouTube Video: 5 Tips for Better Video Presentations*
  - *60-Second Short / TikTok Hook Script*
  - *Executive Briefing & Pitch*

### 5. Video Takes Gallery
- Records MP4 takes locally to the app's video directory.
- Logs file size, duration, date, and associated script name.
- Review and manage takes directly in-app.

---

## App Architecture

```
lib/
├── main.dart                       # App entry point, orientation lock, dark theme boot
├── models/
│   ├── script.dart                 # Script data model, markers extractor, WPM calculator
│   ├── teleprompter_settings.dart  # Prompter speed, fonts, margins, mirror & guide configs
│   └── recorded_video.dart         # Video takes metadata model
├── services/
│   ├── camera_service.dart         # Camera lifecycle, front/back toggle, video recording & mock fallback
│   └── storage_service.dart        # SharedPreferences persistence & default scripts seeder
├── screens/
│   ├── script_list_screen.dart     # Home screen with search, quick launch buttons & templates
│   ├── script_editor_screen.dart   # Text editor with live stats, marker inserter & studio shortcuts
│   ├── studio_recording_screen.dart# In-camera recording studio with eye-contact prompter overlay
│   ├── prompter_screen.dart        # Fullscreen / glass-rig prompter with mirror flip X/Y
│   └── recordings_screen.dart      # Video takes history and management
├── widgets/
│   ├── prompter_view.dart          # Frame-synced smooth ticker scroller & mirror renderer
│   ├── prompter_hud_controls.dart  # Floating HUD (Speed, Play/Pause, Font, Markers, Mirror)
│   ├── prompter_settings_sheet.dart# Customization sheet (speed, typography, guide, margins)
│   └── reading_guide_painter.dart  # Custom canvas painter for eye-level reading guides
└── theme/
    └── app_theme.dart              # Studio dark slate theme with high contrast cues
```

---

## Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run tests**:
   ```bash
   flutter test
   ```

3. **Run on device or emulator**:
   ```bash
   flutter run
   ```
