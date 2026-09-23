import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/core/errors/app_exception.dart';
import 'package:pawpedia/core/network/breed_api_client.dart';
import 'package:pawpedia/models/breed.dart';
import 'package:pawpedia/models/breed_draft.dart';

/// Runs the real client against a real API. Skipped unless both variables are
/// set, so `flutter test` stays offline by default.
///
/// Against the local dev server:
///   PAWPEDIA_API_BASE_URL=http://127.0.0.1:8080/api
///   PAWPEDIA_API_TOKEN=dev-token
///
/// Against Freehostia, once server/ is deployed:
///   PAWPEDIA_API_BASE_URL=http://dogbreeds.mooo.com/api
///   PAWPEDIA_API_TOKEN=(your token)
void main() {
  final String? baseUrl = Platform.environment['PAWPEDIA_API_BASE_URL'];
  final String? token = Platform.environment['PAWPEDIA_API_TOKEN'];
  final bool configured = (baseUrl ?? '').isNotEmpty && (token ?? '').isNotEmpty;
  final Object skip = configured
      ? false
      : 'Set PAWPEDIA_API_BASE_URL and PAWPEDIA_API_TOKEN to run against a live API';

  group('live breed API', () {
    late BreedApiClient client;

    setUp(() => client = BreedApiClient(baseUrl: baseUrl, token: token));
    tearDown(() => client.dispose());

    test('lists every breed and each one parses', () async {
      final List<Map<String, dynamic>> rows = await client.fetchBreeds();

      // Two per page forces several round trips through links.next.
      final BreedApiClient paged = BreedApiClient(baseUrl: baseUrl, token: token, pageSize: 2);
      final List<Map<String, dynamic>> pagedRows = await paged.fetchBreeds();
      paged.dispose();
      expect(pagedRows.length, rows.length, reason: 'paging must return the same rows');

      expect(rows, isNotEmpty);
      final List<Breed> breeds = rows.map(Breed.fromJson).toList();
      expect(breeds.every((Breed b) => b.id > 0), isTrue);
      expect(breeds.map((Breed b) => b.id).toSet().length, breeds.length,
          reason: 'pagination must not repeat or skip rows');
    });

    test('fetches one breed by id', () async {
      final List<Map<String, dynamic>> rows = await client.fetchBreeds();
      final Breed first = Breed.fromJson(rows.first);

      final Map<String, dynamic>? row = await client.fetchBreed(first.id);

      expect(row, isNotNull);
      expect(Breed.fromJson(row!).name, first.name);
    });

    test('an id that does not exist is null', () async {
      expect(await client.fetchBreed(2147483647), isNull);
    });

    // Writes to whichever database the API serves, then deletes what it made.
    test('create, update and delete round trip', () async {
      final String name = 'Live Test Pup ${DateTime.now().millisecondsSinceEpoch}';
      int? id;
      try {
        final Map<String, dynamic> created = await client.createBreed(
          BreedDraft(name: name, originCountry: 'Japan').toJson(),
        );
        id = Breed.fromJson(created).id;
        expect(id, greaterThan(0));
        expect(created['origin_country'], 'Japan');

        final Map<String, dynamic> updated = await client.updateBreed(
          id,
          BreedDraft(name: '$name (edited)', averageLifespan: '13-16 years').toJson(),
        );
        expect(updated['breed_name'], '$name (edited)');
        expect(updated['average_lifespan'], '13-16 years');
        expect(updated['origin_country'], isNull, reason: 'PUT replaces the record');

        final Map<String, dynamic>? reread = await client.fetchBreed(id);
        expect(reread?['breed_name'], '$name (edited)');

        await expectLater(
          client.updateBreed(id, const BreedDraft(name: '').toJson()),
          throwsA(isA<AppException>().having(
              (AppException e) => e.fieldErrors.keys, 'fields', contains('breed_name'))),
        );
      } finally {
        if (id != null) await client.deleteBreed(id);
      }

      expect(await client.fetchBreed(id), isNull, reason: 'the breed is gone');
    });
  }, skip: skip);
}
