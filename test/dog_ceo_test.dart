import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawpedia/core/errors/app_exception.dart';
import 'package:pawpedia/core/network/dog_ceo_client.dart';
import 'package:pawpedia/models/dog_photo.dart';
import 'package:pawpedia/services/dog_photo_service.dart';

/// A slice of the real `GET /breeds/list/all` response.
const Map<String, List<String>> _catalogue = <String, List<String>>{
  'beagle': <String>[],
  'chihuahua': <String>[],
  'collie': <String>['border'],
  'germanshepherd': <String>[],
  'husky': <String>[],
  'labrador': <String>[],
  'papillon': <String>[],
  'poodle': <String>['medium', 'miniature', 'standard', 'toy'],
  'retriever': <String>['chesapeake', 'curly', 'flatcoated', 'golden'],
  'sheepdog': <String>['english', 'indian', 'shetland'],
  'shiba': <String>[],
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  group('DogPhotoService.matchPath', () {
    final Map<String, String?> expected = <String, String?>{
      'Golden Retriever': 'retriever/golden',
      'Border Collie': 'collie/border',
      'Beagle': 'beagle',
      'German Shepherd': 'germanshepherd',
      'Poodle': 'poodle',
      'Labrador Retriever': 'labrador',
      'Siberian Husky': 'husky',
      'Shiba Inu': 'shiba',
      // "sheepdog" has sub-breeds, none of them Polish: no photos beats wrong ones.
      'Polish Lowland Sheepdog': null,
      'Unknown Breed 42': null,
      '': null,
    };

    expected.forEach((String name, String? path) {
      test('"$name" -> $path', () {
        expect(DogPhotoService.matchPath(name, _catalogue), path);
      });
    });
  });

  group('DogPhoto.breedLabelFromUrl', () {
    test('reads sub-breed first, the way people say it', () {
      expect(
        DogPhoto.breedLabelFromUrl(
            'https://images.dog.ceo/breeds/hound-afghan/n02088094_1003.jpg'),
        'Afghan Hound',
      );
    });

    test('a plain breed', () {
      expect(
        DogPhoto.breedLabelFromUrl('https://images.dog.ceo/breeds/beagle/n1.jpg'),
        'Beagle',
      );
    });

    test('null for an unexpected URL', () {
      expect(DogPhoto.breedLabelFromUrl('https://example.com/dog.jpg'), isNull);
    });
  });

  group('DogCeoClient', () {
    test('parses the breed list', () async {
      late Uri seen;
      final DogCeoClient client = DogCeoClient(
        httpClient: MockClient((http.Request request) async {
          seen = request.url;
          return _json(<String, dynamic>{
            'message': <String, dynamic>{
              'beagle': <String>[],
              'retriever': <String>['golden'],
            },
            'status': 'success',
          });
        }),
      );

      final Map<String, List<String>> breeds = await client.fetchBreedList();

      expect(seen.toString(), 'https://dog.ceo/api/breeds/list/all');
      expect(breeds, <String, List<String>>{
        'beagle': <String>[],
        'retriever': <String>['golden'],
      });
    });

    test('requests N images of a breed path', () async {
      late Uri seen;
      final DogCeoClient client = DogCeoClient(
        httpClient: MockClient((http.Request request) async {
          seen = request.url;
          return _json(<String, dynamic>{
            'message': <String>['https://images.dog.ceo/a.jpg'],
            'status': 'success',
          });
        }),
      );

      final List<String> images =
          await client.fetchBreedImages('retriever/golden', count: 3);

      expect(seen.toString(),
          'https://dog.ceo/api/breed/retriever/golden/images/random/3');
      expect(images, <String>['https://images.dog.ceo/a.jpg']);
    });

    test('status "error" becomes an AppException', () async {
      final DogCeoClient client = DogCeoClient(
        httpClient: MockClient((_) async => _json(<String, dynamic>{
              'message': 'Breed not found (master breed does not exist)',
              'status': 'error',
              'code': 404,
            }, 404)),
      );

      await expectLater(
        client.fetchBreedImages('nope'),
        throwsA(isA<AppException>()),
      );
    });
  });

  test('DogPhotoService.photosOf returns nothing for an unmatched breed', () async {
    int imageRequests = 0;
    final DogPhotoService service = DogPhotoService(
      client: DogCeoClient(
        httpClient: MockClient((http.Request request) async {
          if (request.url.path.endsWith('/breeds/list/all')) {
            return _json(<String, dynamic>{'message': _catalogue, 'status': 'success'});
          }
          imageRequests++;
          return _json(<String, dynamic>{'message': <String>[], 'status': 'success'});
        }),
      ),
    );

    expect(await service.photosOf('Polish Lowland Sheepdog'), isEmpty);
    expect(imageRequests, 0);
  });
}
