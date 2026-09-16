import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Every breed photo in the app goes through here.
///
/// Breed pictures are URLs typed into a database by hand, so some will be
/// wrong, some will 404, and some will point at hosts that are slow or gone.
/// A broken link must degrade to a friendly paw placeholder rather than a grey
/// box with an error glyph, and an empty `picture` column must not even attempt
/// a request.
class NetworkBreedImage extends StatelessWidget {
  const NetworkBreedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderIconSize = 32,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double placeholderIconSize;

  @override
  Widget build(BuildContext context) {
    final String? source = url?.trim();
    if (source == null || source.isEmpty || !source.startsWith('http')) {
      return _Placeholder(
        width: width,
        height: height,
        iconSize: placeholderIconSize,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Decode at the size actually drawn. Breed photos are full-resolution
        // camera images; decoding one at 1600x1200 to paint a 68dp thumbnail
        // costs memory and raster time on every card in the list.
        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final double targetWidth = width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : 0);
        final int? memWidth =
            targetWidth > 0 ? (targetWidth * dpr).round() : null;

        return _buildImage(source, memWidth);
      },
    );
  }

  Widget _buildImage(String source, int? memCacheWidth) {
    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (BuildContext context, String _) => _Placeholder(
        width: width,
        height: height,
        iconSize: placeholderIconSize,
        showIcon: false,
      ),
      errorWidget: (BuildContext context, String url, Object error) => _Placeholder(
        width: width,
        height: height,
        iconSize: placeholderIconSize,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    this.width,
    this.height,
    required this.iconSize,
    this.showIcon = true,
  });

  final double? width;
  final double? height;
  final double iconSize;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.skeleton,
      alignment: Alignment.center,
      child: showIcon
          ? Icon(
              Icons.pets_rounded,
              size: iconSize,
              color: AppColors.primary.withValues(alpha: 0.55),
            )
          : null,
    );
  }
}
