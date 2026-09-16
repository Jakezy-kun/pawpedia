import 'package:flutter/foundation.dart';

import '../core/errors/error_mapper.dart';
import '../models/breed.dart';
import '../models/favorite_breed.dart';
import '../services/favorites_service.dart';
import '../services/local_favorites_store.dart';

/// Favourites for whoever is currently using the app.
///
/// Signed-in users read and write `public.favorites`; guests read and write
/// SharedPreferences. Both are the same feature behind the same API — the only
/// difference the UI shows is a banner explaining that guest favourites live on
/// one device.
class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({
    FavoritesService? service,
    LocalFavoritesStore? localStore,
  })  : _service = service ?? FavoritesService(),
        _local = localStore ?? LocalFavoritesStore();

  final FavoritesService _service;
  final LocalFavoritesStore _local;

  String? _userId;
  bool _isGuest = false;
  bool _loading = false;
  List<FavoriteBreed> _favorites = <FavoriteBreed>[];

  List<FavoriteBreed> get favorites => List<FavoriteBreed>.unmodifiable(_favorites);
  int get count => _favorites.length;
  bool get isLoading => _loading;
  bool get isGuest => _isGuest;

  /// True when there is somewhere to save to at all. False only when Supabase
  /// is unconfigured and the user is not in guest mode.
  bool get canSave => _isGuest || _userId != null;

  bool isFavorite(int breedId) =>
      _favorites.any((FavoriteBreed f) => f.breedId == breedId);

  /// Called by the proxy provider whenever auth changes. Reloads from whichever
  /// store now applies, and clears state on sign-out so one account's shortlist
  /// can never be shown to the next person to log in.
  ///
  /// The notify is deferred to a microtask because this runs inside
  /// `ChangeNotifierProxyProvider.update`, which Flutter calls during the build
  /// phase — notifying listeners synchronously from there throws
  /// "setState() called during build".
  void syncWithAuth({required String? userId, required bool isGuest}) {
    if (_userId == userId && _isGuest == isGuest) return;
    _userId = userId;
    _isGuest = isGuest;
    _favorites = <FavoriteBreed>[];

    Future<void>.microtask(() async {
      notifyListeners();
      if (userId != null || isGuest) await load();
    });
  }

  Future<void> load() async {
    if (!canSave) return;
    _loading = true;
    notifyListeners();
    try {
      _favorites = _isGuest && _userId == null
          ? await _local.list()
          : await _service.list(_userId!);
    } catch (error) {
      if (kDebugMode) debugPrint('PawPedia: favourites load failed: $error');
      _favorites = <FavoriteBreed>[];
    }
    _loading = false;
    notifyListeners();
  }

  /// Adds or removes, returning the new state so the caller can pick its
  /// snackbar copy. Updates the list first and rolls back if the write fails,
  /// so the heart responds instantly.
  Future<bool> toggle(Breed breed) async {
    final bool wasFavorite = isFavorite(breed.id);
    if (wasFavorite) {
      await remove(breed.id);
      return false;
    }
    await add(breed);
    return true;
  }

  Future<void> add(Breed breed) async {
    if (!canSave || isFavorite(breed.id)) return;
    final FavoriteBreed favorite = FavoriteBreed.fromBreed(breed);
    final List<FavoriteBreed> previous = _favorites;

    _favorites = <FavoriteBreed>[favorite, ..._favorites];
    notifyListeners();

    try {
      if (_isGuest && _userId == null) {
        await _local.add(favorite);
      } else {
        await _service.add(userId: _userId!, favorite: favorite);
      }
    } catch (error) {
      _favorites = previous;
      notifyListeners();
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Removes optimistically. The caller shows an UNDO snackbar; if the delete
  /// fails the row comes back and the error is rethrown.
  Future<void> remove(int breedId) async {
    final int index =
        _favorites.indexWhere((FavoriteBreed f) => f.breedId == breedId);
    if (index < 0) return;

    final List<FavoriteBreed> previous = _favorites;
    _favorites = List<FavoriteBreed>.from(_favorites)..removeAt(index);
    notifyListeners();

    try {
      if (_isGuest && _userId == null) {
        await _local.remove(breedId);
      } else {
        await _service.remove(userId: _userId!, breedId: breedId);
      }
    } catch (error) {
      _favorites = previous;
      notifyListeners();
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Puts a removed favourite back, for the snackbar's UNDO action.
  Future<void> restore(FavoriteBreed favorite) async {
    if (!canSave || isFavorite(favorite.breedId)) return;
    final List<FavoriteBreed> previous = _favorites;
    _favorites = <FavoriteBreed>[favorite, ..._favorites];
    notifyListeners();

    try {
      if (_isGuest && _userId == null) {
        await _local.add(favorite);
      } else {
        await _service.add(userId: _userId!, favorite: favorite);
      }
    } catch (error) {
      _favorites = previous;
      notifyListeners();
      throw ErrorMapper.fromGenericError(error);
    }
  }

  FavoriteBreed? findById(int breedId) {
    for (final FavoriteBreed favorite in _favorites) {
      if (favorite.breedId == breedId) return favorite;
    }
    return null;
  }

  /// Wipes device-only favourites. Used after account deletion so the next
  /// person on this handset does not inherit a stranger's shortlist.
  Future<void> clearLocal() async {
    await _local.clear();
    _favorites = <FavoriteBreed>[];
    notifyListeners();
  }
}
