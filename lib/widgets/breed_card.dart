import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/breed.dart';
import '../models/favorite_breed.dart';
import 'app_chips.dart';
import 'heart_button.dart';
import 'network_breed_image.dart';

/// The compact row used in the Explore and Search lists.
class BreedListCard extends StatelessWidget {
  const BreedListCard({super.key, required this.breed, required this.onTap});

  final Breed breed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${breed.name}, from ${breed.originCountry}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardR,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardR,
              boxShadow: AppColors.cardShadow,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NetworkBreedImage(
                    url: breed.picture,
                    width: 68,
                    height: 68,
                    placeholderIconSize: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        breed.name,
                        style: text.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      _OriginLine(country: breed.originCountry),
                      if (breed.temperament.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        AmberBadge(label: breed.temperament.first),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two-column tile used on Favorites.
///
/// Rendered entirely from the saved snapshot — name, group and picture are
/// columns on the favourites row — so the grid never makes one breed-API call
/// per tile.
class BreedGridCard extends StatelessWidget {
  const BreedGridCard({
    super.key,
    required this.favorite,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteBreed favorite;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardR,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.cardR,
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Expanded, not a fixed aspect ratio: the tile height is set by
              // the grid, so letting the photo absorb whatever the caption does
              // not use means no dead space at the default text size and no
              // overflow when the caption grows at large ones.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.card),
                      ),
                      child: NetworkBreedImage(url: favorite.picture),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: HeartButton(
                        isFavorite: true,
                        breedName: favorite.breedName,
                        onTap: onRemove,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      favorite.breedName,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((favorite.breedGroup ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        favorite.breedGroup!,
                        style: text.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class _OriginLine extends StatelessWidget {
  const _OriginLine({required this.country});

  final String country;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.location_on_rounded,
          size: 14,
          color: AppColors.primary,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            country,
            style: Theme.of(context).textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
