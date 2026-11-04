import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/main.dart';
import 'package:teleprompter/screens/onboarding_screen.dart';
import 'package:teleprompter/screens/script_list_screen.dart';
import 'package:teleprompter/services/storage_service.dart';

Future<StorageService> _freshStorage([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  final storage = StorageService();
  await storage.resetForTesting();
  return storage;
}

/// Lets the splash animation run, hold, and fade to onboarding.
Future<void> _playSplash(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('StorageService.isFirstLaunch', () {
    test('is true on a fresh install', () async {
      final storage = await _freshStorage();

      expect(await storage.isFirstLaunch(), isTrue);
    });

    test('is false once onboarding is complete', () async {
      final storage = await _freshStorage();
      await storage.markOnboardingComplete();

      expect(await storage.isFirstLaunch(), isFalse);
    });

    test('is false when updating an install that already has scripts', () async {
      final storage = await _freshStorage({'teleprompter_scripts_v1': <String>[]});

      expect(await storage.isFirstLaunch(), isFalse);
    });
  });

  testWidgets('first launch goes splash → onboarding → home and is remembered', (tester) async {
    final storage = await _freshStorage();
    await tester.pumpWidget(const CuevantaApp(showIntroduction: true));

    await _playSplash(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('GET STARTED'));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptListScreen), findsOneWidget);
    expect(await storage.isFirstLaunch(), isFalse);
  });

  testWidgets('skip on the first page goes straight home', (tester) async {
    await _freshStorage();
    await tester.pumpWidget(const CuevantaApp(showIntroduction: true));
    await _playSplash(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptListScreen), findsOneWidget);
  });

  testWidgets('later launches open the home screen directly', (tester) async {
    await _freshStorage();
    await tester.pumpWidget(const CuevantaApp(showIntroduction: false));
    await tester.pumpAndSettle();

    expect(find.byType(ScriptListScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
