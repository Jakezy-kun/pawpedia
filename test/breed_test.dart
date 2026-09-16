import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/models/breed.dart';

void main() {
  group('Breed.fromJson', () {
    test('splits the comma-separated temperament into trimmed traits', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 1,
        'breed_name': 'Golden Retriever',
        'breed_group': 'Sporting',
        'origin_country': 'Scotland',
        'average_lifespan': '10-12 years',
        'temperament': 'Friendly, Intelligent,Devoted ,  Gentle',
        'picture': 'https://example.com/golden.jpg',
      });

      expect(
        breed.temperament,
        <String>['Friendly', 'Intelligent', 'Devoted', 'Gentle'],
      );
    });

    test('accepts an id sent as a string', () {
      // PHP's PDO returns MySQL integers as strings unless the driver is
      // configured otherwise, so both shapes reach the app.
      expect(Breed.fromJson(<String, dynamic>{'id': '42'}).id, 42);
      expect(Breed.fromJson(<String, dynamic>{'id': 42}).id, 42);
    });

    test('falls back to readable text for missing or null columns', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 7,
        'breed_name': null,
        'breed_group': '',
        'origin_country': 'null',
        'average_lifespan': null,
        'temperament': null,
        'picture': null,
      });

      expect(breed.name, 'Unknown breed');
      expect(breed.group, 'Unclassified');
      // The literal string "null" is what a careless PHP json_encode emits;
      // it must never reach the screen.
      expect(breed.originCountry, 'Unknown');
      expect(breed.averageLifespan, 'Unknown');
      expect(breed.temperament, isEmpty);
      expect(breed.picture, '');
    });

    test('drops empty entries from a trailing comma', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 1,
        'temperament': 'Loyal, , Brave,',
      });
      expect(breed.temperament, <String>['Loyal', 'Brave']);
    });

    test('round-trips through toJson', () {
      final Breed original = Breed.fromJson(<String, dynamic>{
        'id': 3,
        'breed_name': 'Beagle',
        'breed_group': 'Hound',
        'origin_country': 'England',
        'average_lifespan': '12-15 years',
        'temperament': 'Curious, Merry',
        'picture': 'https://example.com/beagle.jpg',
      });

      final Breed restored = Breed.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.temperament, original.temperament);
    });
  });

  group('Breed.summary', () {
    test('reads as a sentence with every field present', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 1,
        'breed_name': 'Golden Retriever',
        'breed_group': 'Sporting',
        'origin_country': 'Scotland',
        'average_lifespan': '10-12 years',
        'temperament': 'Friendly, Intelligent, Devoted',
      });

      expect(
        breed.summary,
        'The Golden Retriever is a Sporting group breed from Scotland, best '
        'known for being friendly and intelligent. Most live around 10-12 years.',
      );
    });

    test('omits the parts it has no data for', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 2,
        'breed_name': 'Mystery Dog',
        'breed_group': 'Working',
      });

      expect(breed.summary, 'The Mystery Dog is a Working group breed.');
    });

    test('handles a single temperament without a dangling "and"', () {
      final Breed breed = Breed.fromJson(<String, dynamic>{
        'id': 3,
        'breed_name': 'Test Dog',
        'breed_group': 'Toy',
        'origin_country': 'France',
        'temperament': 'Playful',
      });

      expect(
        breed.summary,
        'The Test Dog is a Toy group breed from France, best known for being '
        'playful.',
      );
    });
  });

  test('groupPillLabel uppercases the group', () {
    final Breed breed = Breed.fromJson(<String, dynamic>{
      'id': 1,
      'breed_group': 'Non-Sporting',
    });
    expect(breed.groupPillLabel, 'NON-SPORTING GROUP');
  });
}
