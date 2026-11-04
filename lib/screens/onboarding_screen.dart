import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cuevanta_logo.dart';

class _OnboardingPage {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
}

/// Three-page introduction shown once, after the first-install splash.
class OnboardingScreen extends StatefulWidget {
  final WidgetBuilder homeScreenBuilder;

  const OnboardingScreen({super.key, required this.homeScreenBuilder});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Duration _pageTransition = Duration(milliseconds: 450);
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.visibility_outlined,
      eyebrow: 'EYE CONTACT',
      title: 'Read right\nunder the lens',
      body: 'Your words scroll just below the front camera, so viewers feel you\'re talking to them, not reading.',
    ),
    _OnboardingPage(
      icon: Icons.auto_stories_outlined,
      eyebrow: 'YOUR WEEK',
      title: 'Every script,\none tap away',
      body: 'Import a weekly READ file and each video becomes its own script, with backup hooks ready to swap in.',
    ),
    _OnboardingPage(
      icon: Icons.radio_button_checked_rounded,
      eyebrow: 'STUDIO',
      title: 'Countdown,\nrecord, share',
      body: 'Recording starts as the countdown ends. Watch each take back and send it straight to your editor.',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _showNextPage() {
    _pageController.nextPage(duration: _pageTransition, curve: Curves.easeOutCubic);
  }

  Future<void> _finishOnboarding() async {
    final navigator = Navigator.of(context);
    await StorageService().markOnboardingComplete();
    navigator.pushReplacement(
      PageRouteBuilder(
        transitionDuration: _pageTransition,
        pageBuilder: (context, _, _) => widget.homeScreenBuilder(context),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _OnboardingPageView(page: _pages[index]),
              ),
            ),
            _PageDots(count: _pages.length, current: _currentPage),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: _GoldButton(
                label: _isLastPage ? 'Get started' : 'Continue',
                onPressed: _isLastPage ? _finishOnboarding : _showNextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          const CuevantaMark(size: 26),
          const SizedBox(width: 10),
          const CuevantaWordmark(fontSize: 12),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isLastPage ? 0 : 1,
            child: TextButton(
              onPressed: _isLastPage ? null : _finishOnboarding,
              style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoldRingIcon(icon: page.icon),
          const SizedBox(height: 48),
          Text(
            page.eyebrow,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.5,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              height: 1.15,
              letterSpacing: -0.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            page.body,
            style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _GoldRingIcon extends StatelessWidget {
  final IconData icon;

  const _GoldRingIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55), width: 1.2),
        gradient: RadialGradient(
          colors: [AppTheme.gold.withValues(alpha: 0.14), Colors.transparent],
        ),
      ),
      child: Icon(icon, color: AppTheme.goldLight, size: 34),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;

  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? AppTheme.gold : AppTheme.gold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GoldButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.goldDeep]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2.5),
          ),
        ),
      ),
    );
  }
}
