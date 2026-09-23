import 'package:flutter/foundation.dart';

/// One dog breed, as served by the PHP/MySQL API.
///
/// Parsing is deliberately forgiving. PHP's PDO returns MySQL integers as
/// strings unless the driver is configured otherwise, so `id` arrives as `5` on
/// one host and `"5"` on another; both have to work. Likewise any text column
/// can come back null, and the UI must show something sensible rather than
/// crash or render the word "null".
@immutable
class Breed {
  const Breed({
    required this.id,
    required this.name,
    required this.group,
    required this.originCountry,
    required this.averageLifespan,
    required this.temperament,
    required this.picture,
  });

  /// Shown when a breed has no group. Not a real group name.
  static const String unknownGroup = 'Unclassified';

  /// Shown for a missing origin or lifespan.
  static const String unknownValue = 'Unknown';

  final int id;
  final String name;
  final String group;
  final String originCountry;
  final String averageLifespan;

  /// `temperament` arrives as a single comma-separated string and is split here
  /// so the rest of the app never has to think about the wire format.
  final List<String> temperament;

  final String picture;

  factory Breed.fromJson(Map<String, dynamic> json) {
    return Breed(
      id: _asInt(json['id']),
      name: _asString(json['breed_name'], fallback: 'Unknown breed'),
      group: _asString(json['breed_group'], fallback: unknownGroup),
      originCountry: _asString(json['origin_country'], fallback: unknownValue),
      averageLifespan:
          _asString(json['average_lifespan'], fallback: unknownValue),
      temperament: _splitTemperament(json['temperament']),
      picture: _asString(json['picture']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'breed_name': name,
        'breed_group': group,
        'origin_country': originCountry,
        'average_lifespan': averageLifespan,
        'temperament': temperament.join(', '),
        'picture': picture,
      };

  /// The one-paragraph summary on the detail screen. Composed from the fields
  /// rather than stored, because the API has no description column.
  String get summary {
    final StringBuffer buffer = StringBuffer('The $name is a $group group breed');
    if (originCountry.isNotEmpty && originCountry != unknownValue) {
      buffer.write(' from $originCountry');
    }
    if (temperament.isNotEmpty) {
      final List<String> traits =
          temperament.take(2).map((String t) => t.toLowerCase()).toList();
      final String phrase =
          traits.length == 2 ? '${traits.first} and ${traits.last}' : traits.first;
      buffer.write(', best known for being $phrase');
    }
    buffer.write('.');
    if (averageLifespan.isNotEmpty && averageLifespan != unknownValue) {
      buffer.write(' Most live around $averageLifespan.');
    }
    return buffer.toString();
  }

  /// `Sporting` becomes `SPORTING GROUP`, for the pill under the detail title.
  String get groupPillLabel => '${group.toUpperCase()} GROUP';

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static String _asString(Object? value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
  }

  static List<String> _splitTemperament(Object? value) {
    final String raw = _asString(value);
    if (raw.isEmpty) return const <String>[];
    return raw
        .split(',')
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) => other is Breed && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
