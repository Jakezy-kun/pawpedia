import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/error_mapper.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/favorite_breed.dart';

/// Reads and writes `public.favorites` for the signed-in user.
///
/// Rows carry a display snapshot of the breed, so listing favourites is one
/// query rather than one query plus N calls to the breed API.
class FavoritesService {
  SupabaseClient get _client => SupabaseBootstrap.client;

  Future<List<FavoriteBreed>> list(String userId) async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map(FavoriteBreed.fromJson).toList();
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Adds a favourite.
  ///
  /// Uses upsert on the (user_id, breed_id) unique constraint so a double tap
  /// — or a tap that raced an earlier one — is a no-op instead of a duplicate
  /// key error surfaced to the user.
  Future<void> add({
    required String userId,
    required FavoriteBreed favorite,
  }) async {
    try {
      // created_at is left to the column default rather than sent from a
      // device whose clock we do not control.
      final Map<String, dynamic> row = favorite.toJson()
        ..remove('created_at')
        ..['user_id'] = userId;

      await _client.from('favorites').upsert(
            row,
            onConflict: 'user_id,breed_id',
            ignoreDuplicates: true,
          );
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Rewrites the display snapshot of a saved breed after the breed itself
  /// was edited. `add` cannot do this: it deliberately ignores duplicates.
  Future<void> updateSnapshot({
    required String userId,
    required FavoriteBreed favorite,
  }) async {
    try {
      await _client
          .from('favorites')
          .update(<String, dynamic>{
            'breed_name': favorite.breedName,
            'breed_group': favorite.breedGroup,
            'picture': favorite.picture,
          })
          .eq('user_id', userId)
          .eq('breed_id', favorite.breedId);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  Future<void> remove({
    required String userId,
    required int breedId,
  }) async {
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('breed_id', breedId);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }
}
