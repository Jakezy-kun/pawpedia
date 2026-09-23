import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/favorite_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../models/breed.dart';
import '../../providers/breed_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/breed_photo_gallery.dart';
import '../../widgets/heart_button.dart';
import '../../widgets/network_breed_image.dart';
import '../breed_form/breed_form_screen.dart';

/// Full detail for one breed.
///
/// The hero photo runs edge to edge and under the status bar, so the back and
/// favourite controls are positioned against `MediaQuery.viewPadding.top`
/// rather than a guessed status-bar height — that is what keeps them clear of
/// the Dynamic Island on an iPhone 15 Pro and the punch-hole on a Pixel 6.
class BreedDetailScreen extends StatefulWidget {
  const BreedDetailScreen({super.key, required this.breed});

  final Breed breed;

  static Future<void> open(BuildContext context, Breed breed) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BreedDetailScreen(breed: breed)),
    );
  }

  @override
  State<BreedDetailScreen> createState() => _BreedDetailScreenState();
}

class _BreedDetailScreenState extends State<BreedDetailScreen> {
  late Breed _breed = widget.breed;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StatsProvider>().recordView(_breed);
      _refresh();
    });
  }

  /// Pulls fresh detail in the background. The screen already has a cached copy
  /// to show, so a failure here is silent rather than an error state.
  Future<void> _refresh() async {
    final Breed? fresh = await context.read<BreedProvider>().refreshBreed(_breed.id);
    if (mounted && fresh != null && fresh != _breed) {
      setState(() => _breed = fresh);
    }
  }

  /// Opens the pre-filled Edit form (PUT) and shows the saved result here.
  Future<void> _edit() async {
    final Breed? saved = await BreedFormScreen.open(context, breed: _breed);
    if (saved == null || !mounted) return;
    setState(() => _breed = saved);
    context.showSnack('Changes saved');
  }

  /// Asks first, then deletes (DELETE) and leaves the screen.
  Future<void> _delete() async {
    final String name = _breed.name;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text(
          'This removes the breed from the catalogue for everyone using '
          'PawPedia. It cannot be undone.',
        ),
        actions: <Widget>[
          AppTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            color: AppColors.textSecondary,
          ),
          AppTextButton(
            label: 'Delete',
            onPressed: () => Navigator.of(context).pop(true),
            color: AppColors.destructive,
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final BreedProvider breeds = context.read<BreedProvider>();
    final FavoritesProvider favorites = context.read<FavoritesProvider>();

    setState(() => _deleting = true);
    try {
      await breeds.delete(_breed.id);
      unawaited(favorites.forgetBreed(_breed.id));
      if (!mounted) return;
      // Shown by the screen underneath once this one pops.
      context.showSnack('$name deleted');
      Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Size size = MediaQuery.sizeOf(context);
    final bool canEdit = context.select<BreedProvider, bool>(
      (BreedProvider breeds) => breeds.canEdit,
    );
    final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
    final FavoritesProvider favorites = context.watch<FavoritesProvider>();

    // Proportional, not fixed: the same layout has to read well on a 812pt
    // iPhone and a 914dp Pixel. Clamped so it never eats a short screen.
    final double heroHeight = (size.height * 0.42).clamp(260.0, 420.0);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            // Stack rather than two stacked slivers: the content sheet has to
            // paint *over* the bottom of the hero so its rounded top corners
            // reveal the photo behind them.
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight,
                  child: NetworkBreedImage(
                    url: _breed.picture,
                    placeholderIconSize: 64,
                  ),
                ),
                // The only non-positioned child, so it is what sizes the Stack.
                Padding(
                  padding: EdgeInsets.only(top: heroHeight - AppRadii.sheet),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.sheet),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      AppSpacing.xl,
                      AppSpacing.screen,
                      // Clear the home indicator / gesture bar, which the app
                      // now draws behind.
                      AppSpacing.xxl + viewPadding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_breed.name, style: text.displaySmall),
                        const SizedBox(height: AppSpacing.md),
                        AmberBadge(
                          label: _breed.groupPillLabel,
                          uppercase: true,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _StatCards(breed: _breed),
                        const SizedBox(height: AppSpacing.xl),
                        Text(_breed.summary, style: text.bodyLarge),
                        if (_breed.temperament.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          Text('Temperament', style: text.titleLarge),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              for (final String trait in _breed.temperament)
                                TemperamentChip(label: trait),
                            ],
                          ),
                        ],
                        BreedPhotoGallery(breedName: _breed.name),
                        if (canEdit) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxl),
                          SecondaryButton(
                            label: 'Edit breed',
                            icon: Icons.edit_outlined,
                            onPressed: _deleting ? null : _edit,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DestructiveButton(
                            label: 'Delete breed',
                            icon: Icons.delete_outline_rounded,
                            isLoading: _deleting,
                            onPressed: _delete,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating controls. Outside the scroll view so they stay reachable,
          // and offset by the real view padding so they clear the notch.
          Positioned(
            top: viewPadding.top + AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Go back',
                  onTap: () => Navigator.of(context).pop(),
                ),
                HeartButton(
                  isFavorite: favorites.isFavorite(_breed.id),
                  breedName: _breed.name,
                  onTap: () => FavoriteActions.toggle(context, _breed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCards extends StatelessWidget {
  const _StatCards({required this.breed});

  final Breed breed;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatCard(
              icon: Icons.favorite_rounded,
              label: 'LIFESPAN',
              value: breed.averageLifespan,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              icon: Icons.location_on_rounded,
              label: 'ORIGIN',
              value: breed.originCountry,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.cardR,
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppColors.badge,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(label, style: AppTextStyles.badgeLabel()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: text.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
