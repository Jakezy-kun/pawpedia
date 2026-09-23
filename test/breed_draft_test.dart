import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/models/breed.dart';
import 'package:pawpedia/models/breed_draft.dart';

void main() {
  test('fromBreed turns display fallbacks back into empty fields', () {
    final Breed breed = Breed.fromJson(<String, dynamic>{
      'id': 3,
      'breed_name': 'Mystery Mutt',
      'breed_group': null,
      'origin_country': null,
      'average_lifespan': null,
      'temperament': 'Calm,  Shy',
      'picture': null,
    });

    final BreedDraft draft = BreedDraft.fromBreed(breed);

    expect(draft.group, '');
    expect(draft.originCountry, '');
    expect(draft.averageLifespan, '');
    expect(draft.temperament, 'Calm, Shy');
    // Saving it unchanged must not write "Unclassified" or "Unknown".
    expect(draft.toJson(), <String, dynamic>{
      'breed_name': 'Mystery Mutt',
      'breed_group': null,
      'origin_country': null,
      'average_lifespan': null,
      'temperament': 'Calm, Shy',
      'picture': null,
    });
  });

  test('toJson trims, nulls blanks and tidies the temperament list', () {
    const BreedDraft draft = BreedDraft(
      name: '  Shiba Inu ',
      group: ' ',
      temperament: 'alert,, bold ,',
      picture: ' https://images.dog.ceo/breeds/shiba/1.jpg ',
    );

    expect(draft.toJson(), <String, dynamic>{
      'breed_name': 'Shiba Inu',
      'breed_group': null,
      'origin_country': null,
      'average_lifespan': null,
      'temperament': 'alert, bold',
      'picture': 'https://images.dog.ceo/breeds/shiba/1.jpg',
    });
  });

  test('drafts that would save the same body are equal', () {
    const BreedDraft a = BreedDraft(name: 'Beagle', temperament: 'Merry, Curious');
    const BreedDraft b = BreedDraft(name: ' Beagle', temperament: 'Merry,Curious');
    const BreedDraft c = BreedDraft(name: 'Beagles');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}
