import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/error_mapper.dart';
import '../core/theme/app_theme.dart';
import '../services/dog_photo_service.dart';
import 'empty_state.dart';
import 'loading_skeleton.dart';
import 'network_breed_image.dart';

/// "More photos": a strip of pictures of one breed from the third-party Dog
/// CEO API, on Breed Detail.
///
/// Renders nothing when Dog CEO has no matching breed. A breed someone added
/// by hand may simply not be one Dog CEO knows, and an empty section would
/// only look broken.
class BreedPhotoGallery extends StatefulWidget {
  const BreedPhotoGallery({super.key, required this.breedName});

  final String breedName;

  @override
  State<BreedPhotoGallery> createState() => _BreedPhotoGalleryState();
}

class _BreedPhotoGalleryState extends State<BreedPhotoGallery> {
  static const double _tileSize = 120;

  late Future<List<String>> _photos;

  @override
  void initState() {
    super.initState();
    _photos = _load();
  }

  Future<List<String>> _load() =>
      context.read<DogPhotoService>().photosOf(widget.breedName);

  @override
  void didUpdateWidget(BreedPhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The breed was renamed on the Edit screen: its match may have changed.
    if (oldWidget.breedName != widget.breedName) {
      setState(() => _photos = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _photos,
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _Section(
            child: SizedBox(
              height: _tileSize,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    SkeletonBox(
                      width: _tileSize,
                      height: _tileSize,
                      borderRadius: AppRadii.cardR,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _Section(
            child: InfoBanner(
              icon: Icons.wifi_off_rounded,
              message: ErrorMapper.fromGenericError(snapshot.error!).message,
              actionLabel: 'Try again',
              onAction: () => setState(() => _photos = _load()),
            ),
          );
        }

        final List<String> photos = snapshot.data ?? const <String>[];
        if (photos.isEmpty) return const SizedBox.shrink();

        return _Section(
          child: SizedBox(
            height: _tileSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (BuildContext context, int i) => Semantics(
                button: true,
                label: 'Photo ${i + 1} of ${widget.breedName}, open larger',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _showLarge(context, photos[i]),
                  child: ClipRRect(
                    borderRadius: AppRadii.cardR,
                    child: NetworkBreedImage(
                      url: photos[i],
                      width: _tileSize,
                      height: _tileSize,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLarge(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardR),
        child: GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: InteractiveViewer(
            child: NetworkBreedImage(url: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Text('More photos', style: text.titleLarge),
        Text(
          'From the Dog CEO API',
          style: text.labelMedium?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}
