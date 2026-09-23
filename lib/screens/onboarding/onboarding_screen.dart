import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/brand_header.dart';

class _Slide {
  const _Slide({
    required this.eyebrow,
    required this.image,
    required this.headline,
    required this.body,
  });

  final String eyebrow;
  final String image;
  final String headline;
  final String body;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    eyebrow: 'DISCOVER',
    image: 'assets/illustrations/onboarding_breeds.png',
    headline: 'Meet every good dog',
    body: 'A friendly directory of dog breeds from all around the world — made '
        'for curious kids and grown-ups alike.',
  ),
  _Slide(
    eyebrow: 'SEARCH',
    image: 'assets/illustrations/onboarding_search.png',
    headline: 'Search the way you think',
    body: 'Filter by breed group or country of origin and narrow things down '
        'in a couple of taps.',
  ),
  _Slide(
    eyebrow: 'SAVE',
    image: 'assets/illustrations/onboarding_shortlist.png',
    headline: 'Keep a shortlist',
    body: 'Tap the heart on any breed to save the companions you love most and '
        'come back to them later.',
  ),
];

/// Readable line length on tablets and in landscape; phones never reach it.
const double _kMaxContentWidth = 520;

/// Long enough for the parallax to read as motion, short enough that tapping
/// Next never feels like waiting.
const Duration _kPageTurn = Duration(milliseconds: 420);

/// Three skippable slides, shown once.
///
/// Motion is driven by the live scroll position rather than by page-change
/// events, so every effect tracks the user's finger mid-swipe and reverses if
/// they let go early. Everything decorative switches off when the system asks
/// for reduced motion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();

  /// Staggered fade-up of the header, slide and controls on first appearance.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// A slow idle bob on the illustration, so a slide at rest still feels alive.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  /// Fades the screen out before handing over to Login, so the swap AuthGate
  /// performs lands on an empty background instead of cutting mid-content.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  int _index = 0;
  bool _reduceMotion = false;
  bool _started = false;
  bool _finishing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _entrance.value = 1;
      _float
        ..stop()
        ..value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
    }

    if (!_started) {
      _started = true;
      if (!_reduceMotion) _entrance.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    _float.dispose();
    _exit.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  /// The fractional page, e.g. 1.4 while dragging from slide 2 to slide 3.
  double get _page {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? _index.toDouble();
    }
    return _index.toDouble();
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  void _goTo(int page) {
    if (page < 0 || page >= _slides.length) return;
    if (_reduceMotion) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: _kPageTurn,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _goTo(_index + 1);
  }

  /// Marks onboarding complete and nothing more. AuthGate reacts by rendering
  /// Login in place of this screen.
  ///
  /// Do not navigate here as well. A pushReplacement raced AuthGate's rebuild:
  /// when it won, it replaced the root route that *is* AuthGate, after which
  /// nothing reacted to auth changes — "Continue as Guest" and a successful
  /// login both silently did nothing.
  Future<void> _finish() async {
    if (_finishing) return;
    // Read before the await: the provider outlives this screen, the context
    // may not.
    final AuthProvider auth = context.read<AuthProvider>();
    setState(() => _finishing = true);
    HapticFeedback.lightImpact();
    if (!_reduceMotion) await _exit.forward();
    await auth.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    // Android back steps through the slides before it leaves the app.
    return PopScope(
      canPop: _index == 0 || _finishing,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _goTo(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _exit,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeIn.transform(_exit.value);
              return Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, -12 * t),
                  child: child,
                ),
              );
            },
            child: IgnorePointer(
              ignoring: _finishing,
              child: Column(
                children: <Widget>[
                  // --- header ---------------------------------------------
                  _Reveal(
                    animation: _entrance,
                    interval: const Interval(0, 0.5),
                    child: _Gutter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const BrandHeader(),
                            _SkipButton(
                              controller: _controller,
                              page: () => _page,
                              onPressed: _finish,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- slides ---------------------------------------------
                  // Full-bleed, so a slide leaves at the screen edge rather
                  // than vanishing inside the gutter.
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (BuildContext context, int i) =>
                          AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, Widget? _) =>
                            _SlideView(
                          slide: _slides[i],
                          offset: _reduceMotion ? 0 : i - _page,
                          float: _float,
                          entrance: _entrance,
                        ),
                      ),
                    ),
                  ),

                  // --- controls -------------------------------------------
                  _Reveal(
                    animation: _entrance,
                    interval: const Interval(0.45, 1),
                    child: _Gutter(
                      child: Column(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: _PageIndicator(
                              controller: _controller,
                              count: _slides.length,
                              index: _index,
                              page: () => _page,
                              onDotTap: _goTo,
                            ),
                          ),
                          _MorphingButton(
                            label: _isLast ? 'Get Started' : 'Next',
                            icon: _isLast
                                ? Icons.pets_rounded
                                : Icons.arrow_forward_rounded,
                            onPressed: _next,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                            ),
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
                                AppTextButton(
                                  label: 'Log in',
                                  onPressed: _finish,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide
// ---------------------------------------------------------------------------

class _SlideView extends StatelessWidget {
  const _SlideView({
    required this.slide,
    required this.offset,
    required this.float,
    required this.entrance,
  });

  final _Slide slide;

  /// Where this slide sits relative to the centre: 0 when fully shown, -1 one
  /// page off to the left, +1 one page off to the right.
  final double offset;

  final Animation<double> float;
  final Animation<double> entrance;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double t = offset.clamp(-1.0, 1.0);
    final double distance = t.abs();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        // Each layer moves at its own speed. The illustration trails the page
        // and the text runs ahead of it in steps, which gives depth and makes
        // the copy read as arriving line by line.
        Widget layer({required double speed, required Widget child}) {
          return Transform.translate(
            offset: Offset(t * width * speed, 0),
            child: Opacity(
              opacity: (1 - distance * 1.6).clamp(0.0, 1.0),
              child: child,
            ),
          );
        }

        // Clip vertically only. The scroll view has to keep large text from
        // painting over the header and dots, but a horizontal clip would slice
        // through the parallax layers at the slide's edge.
        return ClipRect(
          clipper: const _VerticalClip(),
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            // Scrollable so the largest system font sizes cannot overflow the
            // slide on a short viewport.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    _Reveal(
                      animation: entrance,
                      interval: const Interval(0.1, 0.65),
                      child: Transform.translate(
                        offset: Offset(-t * width * 0.35, 0),
                        child: Transform.rotate(
                          angle: t * 0.08,
                          child: Transform.scale(
                            scale: 1 - distance * 0.15,
                            child: Opacity(
                              opacity: (1 - distance * 0.8).clamp(0.0, 1.0),
                              child: _Illustration(
                                image: slide.image,
                                float: float,
                                settle: 1 - distance,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _Reveal(
                      animation: entrance,
                      interval: const Interval(0.25, 0.8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          layer(
                            speed: 0.12,
                            child: Text(
                              slide.eyebrow,
                              style: AppTextStyles.badgeLabel(
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          layer(
                            speed: 0.22,
                            child: Text(
                              slide.headline,
                              style: text.displaySmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          layer(
                            speed: 0.36,
                            child: Text(slide.body, style: text.bodyLarge),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.image,
    required this.float,
    required this.settle,
  });

  final String image;
  final Animation<double> float;

  /// 1 when the slide is centred, falling to 0 as it leaves. Scales the idle
  /// bob so it never fights the user's swipe.
  final double settle;

  @override
  Widget build(BuildContext context) {
    final Widget picture = DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.asset(
            image,
            fit: BoxFit.cover,
            // The illustration is decorative; the headline below it already
            // carries the meaning.
            excludeFromSemantics: true,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                Container(
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
    );

    return AnimatedBuilder(
      animation: float,
      child: picture,
      builder: (BuildContext context, Widget? child) {
        final double bob =
            math.sin(Curves.easeInOut.transform(float.value) * math.pi) * 6;
        return Transform.translate(
          offset: Offset(0, -bob * settle),
          child: child,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// Dots that stretch and recolour continuously with the swipe, rather than
/// snapping when the page changes. Tapping a dot jumps to that slide.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.controller,
    required this.count,
    required this.index,
    required this.page,
    required this.onDotTap,
  });

  final PageController controller;
  final int count;
  final int index;
  final double Function() page;
  final ValueChanged<int> onDotTap;

  static const double _dot = 8;
  static const double _active = 28;

  @override
  Widget build(BuildContext context) {
    // One announcement for the group; the dots themselves are a visual
    // shortcut, and swiping or "Next" covers the same ground for everyone.
    return Semantics(
      label: 'Slide ${index + 1} of $count',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? _) {
          final double p = page();
          return Row(
            children: <Widget>[
              for (int i = 0; i < count; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDotTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: AppSpacing.md,
                    ),
                    child: Builder(
                      builder: (BuildContext context) {
                        final double f =
                            (1 - (i - p).abs()).clamp(0.0, 1.0);
                        return Container(
                          height: _dot,
                          width: _dot + (_active - _dot) * f,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              AppColors.border,
                              AppColors.primary,
                              f,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Fades out as the last slide comes in, where "Get Started" makes it
/// redundant. Its space stays reserved so the header never shifts.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.controller,
    required this.page,
    required this.onPressed,
  });

  final PageController controller;
  final double Function() page;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double remaining = (_slides.length - 1 - page()).clamp(0.0, 1.0);
        final bool hidden = remaining < 0.5;
        return IgnorePointer(
          ignoring: hidden,
          child: ExcludeSemantics(
            excluding: hidden,
            child: Opacity(opacity: remaining, child: child),
          ),
        );
      },
      child: AppTextButton(
        label: 'Skip',
        onPressed: onPressed,
        color: AppColors.textSecondary,
        bold: false,
      ),
    );
  }
}

/// The primary call to action, styled to match [PrimaryButton], whose label
/// and icon roll over in place when they change instead of snapping.
///
/// A separate widget rather than an [AnimatedSwitcher] around [PrimaryButton]:
/// cross-fading two whole buttons dims the fill halfway through.
class _MorphingButton extends StatelessWidget {
  const _MorphingButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.buttonR),
            textStyle: Theme.of(context).textTheme.labelLarge,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.6),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey<String>(label),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: AppSpacing.sm),
                Icon(icon, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Screen gutter plus a maximum width, for everything outside the slides.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Fades and lifts [child] into place during its slice of [animation].
///
/// Stateful because slides rebuild on every scroll frame, and a
/// [CurvedAnimation] made in build would leave a listener behind each time.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.animation,
    required this.interval,
    required this.child,
  });

  final Animation<double> animation;
  final Interval interval;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  late CurvedAnimation _curved;
  late Animation<Offset> _lift;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.interval.begin != widget.interval.begin ||
        oldWidget.interval.end != widget.interval.end) {
      _curved.dispose();
      _build();
    }
  }

  void _build() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(
        widget.interval.begin,
        widget.interval.end,
        curve: Curves.easeOutCubic,
      ),
    );
    _lift = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_curved);
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _lift, child: widget.child),
    );
  }
}

class _VerticalClip extends CustomClipper<Rect> {
  const _VerticalClip();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, 0, size.width * 2, size.height);

  @override
  bool shouldReclip(_VerticalClip oldClipper) => false;
}
