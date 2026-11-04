import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/models/script.dart';
import 'package:teleprompter/models/teleprompter_settings.dart';
import 'package:teleprompter/screens/script_editor_screen.dart';
import 'package:teleprompter/services/storage_service.dart';
import 'package:teleprompter/widgets/prompter_hud_controls.dart';
import 'package:teleprompter/widgets/prompter_view.dart';

Script _sampleScript() => Script(
      id: 's1',
      title: 'Sample',
      content: '[INTRO]\nHello there.\n\n[OUTRO]\nGoodbye.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('HUD controls fit a narrow phone width without overflowing', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(Center(
      child: PrompterHudControls(
        controller: null,
        script: _sampleScript(),
        settings: TeleprompterSettings(),
        isPlaying: false,
        currentSpeed: 38,
        currentFontSize: 28,
        onSpeedChanged: (_) {},
        onFontSizeChanged: (_) {},
        onToggleMirror: () {},
        onOpenSettings: () {},
      ),
    )));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Prompter applies a mirror change made after it was built', (tester) async {
    final settings = TeleprompterSettings(countdownDuration: 0);
    late StateSetter rebuild;

    await tester.pumpWidget(_app(StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return PrompterView(script: _sampleScript(), settings: settings);
    })));

    rebuild(() => settings.mirrorHorizontal = true);
    await tester.pump();

    final transform = tester.widget<Transform>(
      find.descendant(of: find.byType(PrompterView), matching: find.byType(Transform)).first,
    );
    expect(transform.transform.storage[0], -1.0);

    await tester.pumpWidget(const SizedBox());
  });

  test('Deleting every script does not bring back the sample scripts', () async {
    final storage = StorageService();
    for (final script in await storage.getScripts()) {
      await storage.deleteScript(script.id);
    }

    expect(await storage.getScripts(), isEmpty);
  });

  testWidgets('Leaving a blank new script does not save it', (tester) async {
    final storage = StorageService();
    await storage.saveScripts([]);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScriptEditorScreen()),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(await storage.getScripts(), isEmpty);
  });
}
