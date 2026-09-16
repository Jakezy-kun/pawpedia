import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/breed.dart';
import '../models/favorite_breed.dart';
import '../providers/favorites_provider.dart';
import 'constants.dart';
import 'errors/app_exception.dart';
import 'ui_feedback.dart';

/// Favourite toggling shared by Explore, Search and Breed Detail, so a heart
/// behaves identically wherever it appears.
abstract final class FavoriteActions {
  static Future<void> toggle(BuildContext context, Breed breed) async {
    final FavoritesProvider favorites = context.read<FavoritesProvider>();
    final bool wasFavorite = favorites.isFavorite(breed.id);

    try {
      await favorites.toggle(breed);
      if (!context.mounted) return;
      if (!wasFavorite) {
        context.showSnack(
          favorites.isGuest
              ? 'Saved to this device'
              : '${breed.name} added to favorites',
        );
      }
    } on AppException catch (error) {
      if (context.mounted) context.showErrorSnack(error.message);
    }
  }

  /// Removes a favourite and offers an UNDO.
  ///
  /// The row disappears immediately and comes back if the delete fails, so the
  /// grid never stalls waiting on the network. The snackbar is the safety net
  /// for the far more likely mistake: tapping the wrong heart.
  static Future<void> removeWithUndo(
    BuildContext context,
    FavoriteBreed favorite,
  ) async {
    final FavoritesProvider favorites = context.read<FavoritesProvider>();

    try {
      await favorites.remove(favorite.breedId);
    } on AppException catch (error) {
      if (context.mounted) context.showErrorSnack(error.message);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${favorite.breedName} removed'),
          duration: AppDurations.undoWindow,
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => favorites.restore(favorite),
          ),
        ),
      );
  }
}
