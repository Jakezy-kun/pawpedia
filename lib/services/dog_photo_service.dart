import '../core/network/dog_ceo_client.dart';
import '../models/dog_photo.dart';

/// Dog photos from the third-party Dog CEO API, matched to PawPedia's breeds.
///
/// Our catalogue says "Golden Retriever"; Dog CEO files it under
/// `retriever/golden`. [matchPath] bridges the two, using Dog CEO's own breed
/// list, which is fetched once and kept for the life of the app.
class DogPhotoService {
  DogPhotoService({DogCeoClient? client}) : _client = client ?? DogCeoClient();

  final DogCeoClient _client;
  Future<Map<String, List<String>>>? _breedList;

  Future<DogPhoto> randomDog() async =>
      DogPhoto.fromUrl(await _client.fetchRandomImage());

  /// Photos of one of our breeds, or an empty list when Dog CEO has no
  /// matching breed.
  Future<List<String>> photosOf(String breedName, {int count = 6}) async {
    final String? path = await pathFor(breedName);
    if (path == null) return const <String>[];
    return _client.fetchBreedImages(path, count: count);
  }

  /// A single photo for a breed name, falling back to any dog when the name
  /// has no match. Used to suggest a picture on the Add / Edit form.
  Future<String> suggestPhoto(String breedName) async {
    final List<String> photos = await photosOf(breedName, count: 1);
    return photos.isNotEmpty ? photos.first : (await randomDog()).url;
  }

  /// Dog CEO's path for one of our breed names, or null.
  Future<String?> pathFor(String breedName) async {
    try {
      _breedList ??= _client.fetchBreedList();
      return matchPath(breedName, await _breedList!);
    } catch (_) {
      // Let the next call try again rather than caching the failure.
      _breedList = null;
      rethrow;
    }
  }

  void dispose() => _client.dispose();

  /// Finds [breedName] in Dog CEO's [catalogue] (breed -> sub-breeds).
  ///
  /// Tried in order, most specific first:
  ///   1. a sub-breed and breed that together make the whole name
  ///      ("Golden Retriever" -> retriever/golden, "Border Collie" -> collie/border)
  ///   2. the whole name is a breed ("Beagle", "German Shepherd" -> germanshepherd)
  ///   3. one word is a breed that has no sub-breeds
  ///      ("Siberian Husky" -> husky, "Labrador Retriever" -> labrador)
  ///
  /// Step 3 skips breeds with sub-breeds on purpose: "Polish Lowland Sheepdog"
  /// must not show photos of Shetland sheepdogs.
  static String? matchPath(
    String breedName,
    Map<String, List<String>> catalogue,
  ) {
    final List<String> words = breedName
        .toLowerCase()
        .split(RegExp('[^a-z]+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    final String joined = words.join();

    for (final MapEntry<String, List<String>> entry in catalogue.entries) {
      for (final String sub in entry.value) {
        if (joined == '$sub${entry.key}' || joined == '${entry.key}$sub') {
          return '${entry.key}/$sub';
        }
      }
    }

    if (catalogue.containsKey(joined)) return joined;

    for (final String word in words) {
      final List<String>? subs = catalogue[word];
      if (subs != null && subs.isEmpty) return word;
    }
    return null;
  }
}
