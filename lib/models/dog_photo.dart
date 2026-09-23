import 'package:flutter/foundation.dart';

/// One photo from the Dog CEO API, with the breed read from its URL.
///
/// Dog CEO does not return a breed name alongside a random photo, but every
/// image URL names it: `.../breeds/hound-afghan/n02088094_1003.jpg` is an
/// Afghan Hound (sub-breed first, the way people say it).
@immutable
class DogPhoto {
  const DogPhoto({required this.url, required this.breedLabel});

  factory DogPhoto.fromUrl(String url) =>
      DogPhoto(url: url, breedLabel: breedLabelFromUrl(url));

  final String url;

  /// "Afghan Hound", or null if the URL does not follow the usual pattern.
  final String? breedLabel;

  static String? breedLabelFromUrl(String url) {
    final List<String> segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final int index = segments.indexOf('breeds');
    if (index < 0 || index + 1 >= segments.length) return null;

    final List<String> parts = segments[index + 1]
        .split('-')
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    // "hound-afghan" -> "Afghan Hound"
    return parts.reversed.map(_capitalise).join(' ');
  }

  static String _capitalise(String word) =>
      word[0].toUpperCase() + word.substring(1);
}
