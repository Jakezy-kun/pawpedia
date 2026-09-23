import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_mapper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../models/dog_photo.dart';
import '../services/dog_photo_service.dart';
import 'loading_skeleton.dart';
import 'network_breed_image.dart';

/// A random dog photo from the third-party Dog CEO API, on the Explore
/// dashboard. "Show another" fetches a fresh one.
///
/// The previous photo stays on screen while the next one loads, so the card
/// never collapses to a skeleton after the first fetch.
class RandomDogCard extends StatefulWidget {
  const RandomDogCard({super.key});

  @override
  State<RandomDogCard> createState() => _RandomDogCardState();
}

class _RandomDogCardState extends State<RandomDogCard> {
  DogPhoto? _photo;
  AppException? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  Future<void> _next() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DogPhoto photo = await context.read<DogPhotoService>().randomDog();
      if (mounted) setState(() => _photo = photo);
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMapper.fromGenericError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 10,
            child: _buildImage(text),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('RANDOM DOG', style: AppTextStyles.badgeLabel()),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _photo?.breedLabel ?? (_photo == null ? '…' : 'Mystery pup'),
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Live from the Dog CEO API',
                        style: text.labelMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _loading ? null : _next,
                  icon: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryDeep,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Show another'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDeep,
                    minimumSize: const Size(
                      AppSpacing.minTouchTarget,
                      AppSpacing.minTouchTarget,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(TextTheme text) {
    final DogPhoto? photo = _photo;
    if (photo != null) {
      return Semantics(
        image: true,
        label: 'Photo of ${photo.breedLabel ?? 'a dog'}',
        child: NetworkBreedImage(url: photo.url, placeholderIconSize: 48),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: AppColors.skeleton,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.wifi_off_rounded,
                    color: AppColors.textSecondary, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!.message,
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SkeletonBox(height: double.infinity);
  }
}
