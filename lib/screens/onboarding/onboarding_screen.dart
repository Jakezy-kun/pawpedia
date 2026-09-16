import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/brand_header.dart';

class _Slide {
  const _Slide({
    required this.image,
    required this.headline,
    required this.body,
  });

  final String image;
  final String headline;
  final String body;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    image: 'assets/illustrations/onboarding_breeds.png',
    headline: 'Meet every good dog',
    body: 'A friendly directory of dog breeds from all around the world — made '
        'for curious kids and grown-ups alike.',
  ),
  _Slide(
    image: 'assets/illustrations/onboarding_search.png',
    headline: 'Search the way you think',
    body: 'Filter by breed group or country of origin and narrow things down '
        'in a couple of taps.',
  ),
  _Slide(
    image: 'assets/illustrations/onboarding_shortlist.png',
    headline: 'Keep a shortlist',
    body: 'Tap the heart on any breed to save the companions you love most and '
        'come back to them later.',
  ),
];

/// Three skippable slides, shown once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Marks onboarding complete and nothing more. AuthGate reacts by rendering
  /// Login in place of this screen.
  ///
  /// Do not navigate here as well. A pushReplacement raced AuthGate's rebuild:
  /// when it won, it replaced the root route that *is* AuthGate, after which
  /// nothing reacted to auth changes — "Continue as Guest" and a successful
  /// login both silently did nothing.
  Future<void> _finish() => context.read<AuthProvider>().completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Column(
            children: <Widget>[
              // --- header -------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const BrandHeader(),
                    AppTextButton(
                      label: 'Skip',
                      onPressed: _finish,
                      color: AppColors.textSecondary,
                      bold: false,
                    ),
                  ],
                ),
              ),

              // --- slides -------------------------------------------------
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (int i) => setState(() => _index = i),
                  itemBuilder: (BuildContext context, int i) =>
                      _SlideView(slide: _slides[i]),
                ),
              ),

              // --- dots ---------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        height: 7,
                        width: i == _index ? 26 : 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
              ),

              PrimaryButton(
                label: _isLast ? 'Get Started' : 'Next',
                onPressed: _next,
              ),

              // --- footer -------------------------------------------------
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Already have an account?',
                        style: text.labelMedium,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    AppTextButton(label: 'Log in', onPressed: _finish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    // Scrollable so the largest system font sizes cannot overflow the slide on
    // a short viewport.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                slide.image,
                fit: BoxFit.cover,
                // The illustration is decorative; the headline beside it
                // already carries the meaning.
                excludeFromSemantics: true,
                errorBuilder: (BuildContext _, Object _, StackTrace? _) => Container(
                  color: AppColors.badge,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.pets_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(slide.headline, style: text.displaySmall),
          const SizedBox(height: AppSpacing.md),
          Text(slide.body, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
