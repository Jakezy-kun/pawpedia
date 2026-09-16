import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_breed.dart';

/// Guest-mode favourites, stored in SharedPreferences on this handset.
///
/// Guests get the real feature, not a disabled button — they just do not get
/// sync, which the UI states plainly wherever these are shown. Kept in the same
/// JSON shape as the Supabase rows so the two stores are interchangeable
/// behind `FavoritesProvider`, and so a future "import my guest favourites on
/// sign-up" step is a straight read-and-insert.
class LocalFavoritesStore {
  static const String _key = 'pawpedia.guest_favorites.v1';

  Future<List<FavoriteBreed>> list() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <FavoriteBreed>[];

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<FavoriteBreed> favorites = decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) =>
              FavoriteBreed.fromJson(row.cast<String, dynamic>()))
          .toList();
      // Newest first, matching the Supabase ordering.
      favorites.sort((FavoriteBreed a, FavoriteBreed b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return favorites;
    } catch (error) {
      // Corrupted store: drop it rather than crashing on every launch.
      if (kDebugMode) debugPrint('PawPedia: guest favourites unreadable: $error');
      await prefs.remove(_key);
      return <FavoriteBreed>[];
    }
  }

  Future<void> add(FavoriteBreed favorite) async {
    final List<FavoriteBreed> current = await list();
    if (current.contains(favorite)) return;
    await _write(<FavoriteBreed>[favorite, ...current]);
  }

  Future<void> remove(int breedId) async {
    final List<FavoriteBreed> current = await list();
    current.removeWhere((FavoriteBreed f) => f.breedId == breedId);
    await _write(current);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _write(List<FavoriteBreed> favorites) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(favorites.map((FavoriteBreed f) => f.toJson()).toList()),
    );
  }
}
