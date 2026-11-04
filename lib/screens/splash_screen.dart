import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/cuevanta_logo.dart';

/// Brand intro shown once, on first install: the ring draws itself in,
/// then the wordmark and tagline fade up.
class SplashScreen extends StatefulWidget {
  final WidgetBuilder nextScreenBuilder;

  const SplashScreen({super.key, required this.nextScreenBuilder});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 2200);
  static const Duration _holdAfterAnimation = Duration(milliseconds: 500);
  static const Duration _exitFadeDuration = Duration(milliseconds: 600);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _animationDuration);

  late final Animation<double> _ringProgress =
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.55, curve: Curves.easeInOutCubic));
  late final Animation<double> _wordmarkReveal =
      CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.85, curve: Curves.easeOut));
  late final Animation<double> _taglineReveal =
      CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(_goToNextScreen);
  }

  Future<void> _goToNextScreen() async {
    await Future.delayed(_holdAfterAnimation);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _exitFadeDuration,
        pageBuilder: (context, _, _) => widget.nextScreenBuilder(context),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CuevantaMark(size: 112, progress: _ringProgress.value),
              const SizedBox(height: 36),
              _Reveal(
                progress: _wordmarkReveal.value,
                child: const CuevantaWordmark(fontSize: 22),
              ),
              const SizedBox(height: 14),
              _Reveal(
                progress: _taglineReveal.value,
                child: Text(
                  'SPEAK TO THE LENS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: AppTheme.gold.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades and lifts its child into place as [progress] goes 0 → 1.
class _Reveal extends StatelessWidget {
  static const double _liftDistance = 10;

  final double progress;
  final Widget child;

  const _Reveal({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(offset: Offset(0, (1 - progress) * _liftDistance), child: child),
    );
  }
}
