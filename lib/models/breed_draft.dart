import 'package:flutter/foundation.dart';

import 'breed.dart';

/// The editable fields of a breed, as the Add / Edit form holds them.
///
/// Kept apart from [Breed] because [Breed] fills gaps with display fallbacks
/// ("Unclassified", "Unknown"). Sending those back on save would write the
/// placeholder text into the database as if someone had typed it.
@immutable
class BreedDraft {
  const BreedDraft({
    required this.name,
    this.group = '',
    this.originCountry = '',
    this.averageLifespan = '',
    this.temperament = '',
    this.picture = '',
  });

  /// The form for an existing breed, with display fallbacks turned back into
  /// empty fields.
  factory BreedDraft.fromBreed(Breed breed) => BreedDraft(
        name: breed.name,
        group: breed.group == Breed.unknownGroup ? '' : breed.group,
        originCountry:
            breed.originCountry == Breed.unknownValue ? '' : breed.originCountry,
        averageLifespan: breed.averageLifespan == Breed.unknownValue
            ? ''
            : breed.averageLifespan,
        temperament: breed.temperament.join(', '),
        picture: breed.picture,
      );

  final String name;
  final String group;
  final String originCountry;
  final String averageLifespan;

  /// Comma-separated, exactly as the API stores it.
  final String temperament;

  final String picture;

  /// The request body for `POST /breeds` and `PUT /breeds/{id}`. Blank
  /// optional fields are sent as null so the database stores no value rather
  /// than an empty string.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'breed_name': name.trim(),
        'breed_group': _orNull(group),
        'origin_country': _orNull(originCountry),
        'average_lifespan': _orNull(averageLifespan),
        'temperament': _orNull(_normaliseTemperament(temperament)),
        'picture': _orNull(picture),
      };

  static String? _orNull(String value) {
    final String text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// "friendly,  alert ,,loyal" becomes "friendly, alert, loyal".
  static String _normaliseTemperament(String value) => value
      .split(',')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(', ');

  /// Equal when saving either would send the same body, so the form can tell
  /// whether anything really changed.
  @override
  bool operator ==(Object other) =>
      other is BreedDraft && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
