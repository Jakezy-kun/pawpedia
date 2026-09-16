import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pawpedia/core/errors/app_exception.dart';
import 'package:pawpedia/core/network/breed_api_client.dart';

const String _base = 'http://api.test/api';
const String _token = 'secret-token';

Map<String, dynamic> _breed(int id, String name) => <String, dynamic>{
      'id': id,
      'breed_name': name,
      'breed_group': 'Toy',
      'origin_country': 'France',
      'average_lifespan': '12-15 years',
      'temperament': 'Friendly, Alert',
      'picture': null,
    };

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );

http.Response _error(int status, String code) => _json(
      <String, dynamic>{
        'error': <String, dynamic>{'status': status, 'code': code, 'message': code},
      },
      status,
    );

BreedApiClient _client(MockClientHandler handler, {String token = _token, String base = _base}) =>
    BreedApiClient(httpClient: MockClient(handler), baseUrl: base, token: token);

void main() {
  group('fetchBreeds', () {
    test('calls GET {base}/breeds with the bearer token', () async {
      late http.Request seen;
      final BreedApiClient client = _client((http.Request request) async {
        seen = request;
        return _json(<String, dynamic>{
          'data': <Object>[_breed(1, 'Papillon')],
          'links': <String, dynamic>{'next': null},
        });
      });

      await client.fetchBreeds();

      expect(seen.method, 'GET');
      expect(seen.url.toString(), 'http://api.test/api/breeds?per_page=100');
      expect(seen.headers['Authorization'], 'Bearer $_token');
      expect(seen.headers['Accept'], 'application/json');
    });

    test('follows links.next until the last page', () async {
      final List<String> requested = <String>[];
      final BreedApiClient client = _client((http.Request request) async {
        requested.add(request.url.toString());
        final String page = request.url.queryParameters['page'] ?? '1';
        return _json(<String, dynamic>{
          'data': <Object>[_breed(int.parse(page), 'Breed $page')],
          'links': <String, dynamic>{
            // Server links are path-absolute, as the PHP API returns them.
            'next': page == '3' ? null : '/api/breeds?page=${int.parse(page) + 1}&per_page=100',
          },
        });
      });

      final List<Map<String, dynamic>> rows = await client.fetchBreeds();

      expect(rows.map((Map<String, dynamic> r) => r['breed_name']), <String>['Breed 1', 'Breed 2', 'Breed 3']);
      expect(requested.last, 'http://api.test/api/breeds?page=3&per_page=100');
    });

    test('refuses a next link on another host, so the token never leaks', () async {
      final BreedApiClient client = _client((http.Request request) async => _json(<String, dynamic>{
            'data': <Object>[],
            'links': <String, dynamic>{'next': 'http://evil.test/api/breeds?page=2'},
          }));

      expect(client.fetchBreeds(), throwsA(isA<AppException>()));
    });

    test('stops a server that loops on the same next link', () async {
      final BreedApiClient client = _client((http.Request request) async => _json(<String, dynamic>{
            'data': <Object>[],
            'links': <String, dynamic>{'next': '/api/breeds?per_page=100'},
          }));

      expect(client.fetchBreeds(), throwsA(isA<AppException>()));
    });

    test('a trailing slash on the base URL does not double up', () async {
      late Uri seen;
      final BreedApiClient client = _client(
        (http.Request request) async {
          seen = request.url;
          return _json(<String, dynamic>{'data': <Object>[], 'links': <String, dynamic>{'next': null}});
        },
        base: 'http://api.test/api/',
      );

      await client.fetchBreeds();

      expect(seen.path, '/api/breeds');
    });

    test('401 is an auth configuration error', () async {
      final BreedApiClient client = _client((http.Request request) async => _error(401, 'unauthorized'));

      await expectLater(
        client.fetchBreeds(),
        throwsA(isA<AppException>().having((AppException e) => e.kind, 'kind', AppErrorKind.apiAuth)),
      );
    });

    test('an unknown route (wrong base URL) is a configuration error', () async {
      final BreedApiClient client = _client((http.Request request) async => _error(404, 'route_not_found'));

      await expectLater(
        client.fetchBreeds(),
        throwsA(isA<AppException>().having((AppException e) => e.kind, 'kind', AppErrorKind.apiAuth)),
      );
    });

    test('503 is reported as a temporary network problem', () async {
      final BreedApiClient client = _client((http.Request request) async => _error(503, 'database_unavailable'));

      await expectLater(
        client.fetchBreeds(),
        throwsA(isA<AppException>().having((AppException e) => e.kind, 'kind', AppErrorKind.network)),
      );
    });

    test('a missing token fails without touching the network', () async {
      bool called = false;
      final BreedApiClient client = _client(
        (http.Request request) async {
          called = true;
          return _json(<String, dynamic>{});
        },
        token: '',
      );

      await expectLater(client.fetchBreeds(), throwsA(isA<AppException>()));
      expect(called, isFalse);
    });

    test('still reads a body with stray output in front of the JSON', () async {
      final BreedApiClient client = _client((http.Request request) async => http.Response(
            '/*  */${jsonEncode(<String, dynamic>{'data': <Object>[_breed(1, 'Beagle')], 'links': <String, dynamic>{'next': null}})}',
            200,
          ));

      expect((await client.fetchBreeds()).single['breed_name'], 'Beagle');
    });
  });

  group('fetchBreed', () {
    test('calls GET {base}/breeds/{id} and returns data', () async {
      late Uri seen;
      final BreedApiClient client = _client((http.Request request) async {
        seen = request.url;
        return _json(<String, dynamic>{'data': _breed(7, 'Siberian Husky')});
      });

      final Map<String, dynamic>? breed = await client.fetchBreed(7);

      expect(seen.toString(), 'http://api.test/api/breeds/7');
      expect(breed?['breed_name'], 'Siberian Husky');
    });

    test('a missing breed returns null rather than throwing', () async {
      final BreedApiClient client = _client((http.Request request) async => _error(404, 'breed_not_found'));

      expect(await client.fetchBreed(999), isNull);
    });
  });
}
