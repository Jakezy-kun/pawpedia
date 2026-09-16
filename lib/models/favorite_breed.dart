import 'package:flutter/foundation.dart';

import 'breed.dart';

/// A saved breed.
///
/// Carries a display snapshot (name, group, picture) rather than just an id.
/// The breeds themselves live in MySQL on another host, so without the
/// snapshot the Favorites grid would need one HTTP round trip per tile just to
/// render. `breedId` is intentionally not a foreign key for the same reason.
@immutable
class FavoriteBreed {
  const FavoriteBreed({
    required this.breedId,
    required this.breedName,
    this.breedGroup,
    this.picture,
    this.createdAt,
  });

  final int breedId;
  final String breedName;
  final String? breedGroup;
  final String? picture;
  final DateTime? createdAt;

  factory FavoriteBreed.fromBreed(Breed breed) => FavoriteBreed(
        breedId: breed.id,
        breedName: breed.name,
        breedGroup: breed.group,
        picture: breed.picture,
        createdAt: DateTime.now(),
      );

  factory FavoriteBreed.fromJson(Map<String, dynamic> json) {
    final Object? rawId = json['breed_id'];
    return FavoriteBreed(
      breedId: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      breedName: json['breed_name']?.toString() ?? 'Unknown breed',
      breedGroup: json['breed_group']?.toString(),
      picture: json['picture']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  /// Shape used for both the Supabase insert and the local guest store.
  /// `user_id` is added by the service, not by the model.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'breed_id': breedId,
        'breed_name': breedName,
        'breed_group': breedGroup,
        'picture': picture,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is FavoriteBreed && other.breedId == breedId;

  @override
  int get hashCode => breedId.hashCode;
}
