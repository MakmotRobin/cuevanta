import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_orientations.dart';
import 'screens/onboarding_screen.dart';
import 'screens/script_list_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(allAppOrientations);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = StorageService();
  await storageService.init();
  final isFirstLaunch = await storageService.isFirstLaunch();

  runApp(CuevantaApp(showIntroduction: isFirstLaunch));
}

class CuevantaApp extends StatelessWidget {
  /// Splash + onboarding before the home screen; true only on a fresh install.
  final bool showIntroduction;

  const CuevantaApp({super.key, required this.showIntroduction});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cuevanta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: showIntroduction ? _introduction() : const ScriptListScreen(),
    );
  }

  Widget _introduction() => SplashScreen(
        nextScreenBuilder: (_) => OnboardingScreen(
          homeScreenBuilder: (_) => const ScriptListScreen(),
        ),
      );
}
