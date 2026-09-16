import 'package:flutter/foundation.dart';

/// A row of `public.profiles`.
///
/// The user's email is deliberately not here: it belongs to `auth.users` and
/// is read from the Supabase session, so there is only ever one copy of it.
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final DateTime? createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    final String rawName = (json['name'] as String?)?.trim() ?? '';
    final String rawPhoto = (json['photo_url'] as String?)?.trim() ?? '';
    return Profile(
      id: json['id'].toString(),
      name: rawName.isEmpty ? 'PawPedia User' : rawName,
      photoUrl: rawPhoto.isEmpty ? null : rawPhoto,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'photo_url': photoUrl,
        'created_at': createdAt?.toIso8601String(),
      };

  Profile copyWith({String? name, String? photoUrl, bool clearPhoto = false}) {
    return Profile(
      id: id,
      name: name ?? this.name,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      createdAt: createdAt,
    );
  }

  /// Up to two letters for the avatar fallback: "Riley Parker" becomes "RP".
  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _take(parts.first, 2);
    return '${_take(parts.first, 1)}${_take(parts.last, 1)}';
  }

  static String _take(String value, int count) =>
      value.substring(0, value.length < count ? value.length : count).toUpperCase();
}
