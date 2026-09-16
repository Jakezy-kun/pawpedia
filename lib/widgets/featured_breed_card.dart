import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../models/breed.dart';
import 'app_chips.dart';
import 'heart_button.dart';
import 'network_breed_image.dart';

/// The "Breed of the Day" hero on Explore.
class FeaturedBreedCard extends StatelessWidget {
  const FeaturedBreedCard({
    super.key,
    required this.breed,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Breed breed;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

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
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadii.card),
                    ),
                    child: AspectRatio(
                      // Wide enough to feel like a hero, short enough that the
                      // card below it stays visible on a 812pt viewport.
                      aspectRatio: 16 / 10,
                      child: NetworkBreedImage(
                        url: breed.picture,
                        placeholderIconSize: 48,
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: HeartButton(
                      isFavorite: isFavorite,
                      breedName: breed.name,
                      onTap: onToggleFavorite,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'BREED OF THE DAY',
                      style: AppTextStyles.badgeLabel(
                        color: AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      breed.name,
                      style: text.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Wraps rather than overflows when the system font is large
                    // or a country name is long.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(breed.originCountry, style: text.bodyMedium),
                          ],
                        ),
                        if (breed.temperament.isNotEmpty)
                          AmberBadge(label: breed.temperament.first),
                      ],
                    ),
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
