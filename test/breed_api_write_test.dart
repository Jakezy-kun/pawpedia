import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawpedia/core/errors/app_exception.dart';
import 'package:pawpedia/core/network/breed_api_client.dart';

const String _base = 'http://api.test/api';
const String _token = 'secret-token';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );

http.Response _error(int status, String code, {Map<String, String>? fields}) =>
    _json(
      <String, dynamic>{
        'error': <String, dynamic>{
          'status': status,
          'code': code,
          'message': 'server says $code',
          'fields': ?fields,
        },
      },
      status,
    );

Map<String, dynamic> _saved(int id, String name) => <String, dynamic>{
      'data': <String, dynamic>{
        'id': id,
        'breed_name': name,
        'breed_group': 'Toy',
        'origin_country': null,
        'average_lifespan': null,
        'temperament': null,
        'picture': null,
      },
      'links': <String, dynamic>{'self': '/api/breeds/$id'},
    };

BreedApiClient _client(MockClientHandler handler) =>
    BreedApiClient(httpClient: MockClient(handler), baseUrl: _base, token: _token);

void main() {
  group('createBreed', () {
    test('POSTs JSON to {base}/breeds with the bearer token', () async {
      late http.Request seen;
      final BreedApiClient client = _client((http.Request request) async {
        seen = request;
        return _json(_saved(11, 'Shiba Inu'), 201);
      });

      final Map<String, dynamic> row =
          await client.createBreed(<String, dynamic>{'breed_name': 'Shiba Inu'});

      expect(seen.method, 'POST');
      expect(seen.url.toString(), 'http://api.test/api/breeds');
      expect(seen.headers['Authorization'], 'Bearer $_token');
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seen.body), <String, dynamic>{'breed_name': 'Shiba Inu'});
      expect(row['id'], 11);
    });

    test('422 carries the per-field messages', () async {
      final BreedApiClient client = _client((_) async => _error(
            422,
            'validation_failed',
            fields: <String, String>{'breed_name': 'Breed name is required.'},
          ));

      await expectLater(
        client.createBreed(<String, dynamic>{}),
        throwsA(isA<AppException>()
            .having((AppException e) => e.kind, 'kind', AppErrorKind.validation)
            .having((AppException e) => e.fieldErrors['breed_name'], 'field',
                'Breed name is required.')),
      );
    });

    test('409 duplicate name is reported against breed_name', () async {
      final BreedApiClient client =
          _client((_) async => _error(409, 'breed_exists'));

      await expectLater(
        client.createBreed(<String, dynamic>{'breed_name': 'Beagle'}),
        throwsA(isA<AppException>()
            .having((AppException e) => e.message, 'message', 'server says breed_exists')
            .having((AppException e) => e.fieldErrors.keys, 'fields', <String>['breed_name'])),
      );
    });

    test('405 from an old server explains the deploy step', () async {
      final BreedApiClient client =
          _client((_) async => _error(405, 'method_not_allowed'));

      await expectLater(
        client.createBreed(<String, dynamic>{'breed_name': 'Beagle'}),
        throwsA(isA<AppException>().having(
            (AppException e) => e.message, 'message', contains('server/'))),
      );
    });
  });

  group('updateBreed', () {
    test('PUTs JSON to {base}/breeds/{id}', () async {
      late http.Request seen;
      final BreedApiClient client = _client((http.Request request) async {
        seen = request;
        return _json(_saved(4, 'Shiba'));
      });

      final Map<String, dynamic> row =
          await client.updateBreed(4, <String, dynamic>{'breed_name': 'Shiba'});

      expect(seen.method, 'PUT');
      expect(seen.url.toString(), 'http://api.test/api/breeds/4');
      expect(jsonDecode(seen.body), <String, dynamic>{'breed_name': 'Shiba'});
      expect(row['breed_name'], 'Shiba');
    });

    test('a breed deleted meanwhile is a clear error', () async {
      final BreedApiClient client =
          _client((_) async => _error(404, 'breed_not_found'));

      await expectLater(
        client.updateBreed(4, <String, dynamic>{'breed_name': 'Shiba'}),
        throwsA(isA<AppException>().having(
            (AppException e) => e.message, 'message', contains('no longer exists'))),
      );
    });
  });

  group('deleteBreed', () {
    test('sends DELETE {base}/breeds/{id} and accepts 204', () async {
      late http.Request seen;
      final BreedApiClient client = _client((http.Request request) async {
        seen = request;
        return http.Response('', 204);
      });

      await client.deleteBreed(7);

      expect(seen.method, 'DELETE');
      expect(seen.url.toString(), 'http://api.test/api/breeds/7');
      expect(seen.headers['Authorization'], 'Bearer $_token');
    });

    test('an already-deleted breed (404) counts as success', () async {
      final BreedApiClient client =
          _client((_) async => _error(404, 'breed_not_found'));

      await client.deleteBreed(7);
    });

    test('401 still fails', () async {
      final BreedApiClient client =
          _client((_) async => _error(401, 'unauthorized'));

      await expectLater(
        client.deleteBreed(7),
        throwsA(isA<AppException>()
            .having((AppException e) => e.kind, 'kind', AppErrorKind.apiAuth)),
      );
    });
  });
}
