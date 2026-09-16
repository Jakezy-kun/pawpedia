import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/favorite_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../models/breed.dart';
import '../../models/favorite_breed.dart';
import '../../providers/auth_provider.dart';
import '../../providers/breed_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/breed_card.dart';
import '../../widgets/empty_state.dart';
import '../breed_detail/breed_detail_screen.dart';
import '../shell/main_shell.dart';

/// The saved shortlist, as a two-column grid.
///
/// Rendered entirely from the snapshot columns on each favourites row, so
/// opening this tab costs one query and no breed-API traffic at all.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int? _openingBreedId;

  /// Fresh detail is fetched on tap, because a snapshot can be months old.
  /// If the fetch fails we still open the screen using what we have rather
  /// than refusing to navigate.
  Future<void> _open(FavoriteBreed favorite) async {
    final BreedProvider breeds = context.read<BreedProvider>();

    Breed? breed = breeds.byId(favorite.breedId);
    if (breed == null) {
      setState(() => _openingBreedId = favorite.breedId);
      breed = await breeds.refreshBreed(favorite.breedId);
      if (mounted) setState(() => _openingBreedId = null);
    }

    if (!mounted) return;
    if (breed == null) {
      context.showErrorSnack(
        'We could not load ${favorite.breedName} right now.',
      );
      return;
    }
    await BreedDetailScreen.open(context, breed);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final FavoritesProvider favorites = context.watch<FavoritesProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Favorites', style: text.displaySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      favorites.count == 1
                          ? '1 breed on your shortlist'
                          : '${favorites.count} breeds on your shortlist',
                      style: text.bodyLarge,
                    ),
                    if (auth.isGuest) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      InfoBanner(
                        message: AppStrings.guestFavoritesNotice,
                        actionLabel: 'Create an account',
                        onAction: () => auth.leaveGuest(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (favorites.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (favorites.favorites.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.pets_rounded,
                  title: 'No favorites yet',
                  message:
                      'Tap the heart on any breed and it will show up here.',
                  actionLabel: 'Explore breeds',
                  onAction: () => context
                      .findAncestorStateOfType<MainShellState>()
                      ?.goToTab(0),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  AppSpacing.xl,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    // The caption takes what it needs and the photo absorbs
                    // the rest, so this ratio only sets the overall tile shape.
                    childAspectRatio: 0.80,
                  ),
                  itemCount: favorites.favorites.length,
                  itemBuilder: (BuildContext context, int i) {
                    final FavoriteBreed favorite = favorites.favorites[i];
                    return Opacity(
                      opacity: _openingBreedId == favorite.breedId ? 0.5 : 1,
                      child: BreedGridCard(
                        favorite: favorite,
                        onTap: () => _open(favorite),
                        onRemove: () =>
                            FavoriteActions.removeWithUndo(context, favorite),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
