import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../constants.dart';
import '../errors/app_exception.dart';
import 'json_sanitizer.dart';

/// Talks to the read-only PHP/MySQL breed API.
///
/// Three things about this server drive the design here, all verified against
/// the live host rather than assumed from the spec:
///
///  1. It has no working HTTPS listener, so requests go out over plain HTTP.
///     That is why Android needs a scoped cleartext permit and iOS an ATS
///     exception for this one domain.
///  2. The REST routes are not under `/api`; the endpoint is `/dogbreeds.php`.
///  3. Every response body is prefixed with a `/*  */` comment injected by the
///     host, which is stripped by [JsonSanitizer] before decoding.
///
/// Whether the server honours `?search=`, `?group=` and `?country=` could not
/// be confirmed without a token, so callers must not depend on it — see
/// `BreedApiService`, which filters locally and treats server-side filtering
/// as an optimisation only.
class BreedApiClient {
  BreedApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  void dispose() => _http.close();

  /// Fetches every breed.
  Future<List<Map<String, dynamic>>> fetchBreeds({
    String? search,
    String? group,
    String? country,
  }) async {
    final Map<String, String> query = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (group != null && group.isNotEmpty) 'group': group,
      if (country != null && country.isNotEmpty) 'country': country,
    };
    final Object? decoded = await _get(query);
    return _asRows(decoded);
  }

  /// Fetches a single breed by its MySQL id.
  ///
  /// Returns null when the server answers successfully but has no such breed,
  /// which the caller treats as "fall back to the cached copy" rather than an
  /// error.
  Future<Map<String, dynamic>?> fetchBreed(int id) async {
    final Object? decoded = await _get(<String, String>{'id': id.toString()});
    final List<Map<String, dynamic>> rows = _asRows(decoded);
    if (rows.isEmpty) return null;
    // Some handlers ignore ?id= and return the whole table; pick the right row
    // rather than trusting position.
    for (final Map<String, dynamic> row in rows) {
      if (int.tryParse(row['id']?.toString() ?? '') == id) return row;
    }
    return rows.length == 1 ? rows.first : null;
  }

  Future<Object?> _get(Map<String, String> query) async {
    if (!AppConfig.hasBreedApi) {
      throw const AppException(
        'The breed API token is missing from .env.',
        kind: AppErrorKind.apiAuth,
      );
    }

    final Uri uri = _buildUri(query);

    late final http.Response response;
    try {
      response = await _http
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${AppConfig.breedApiToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(AppDurations.networkTimeout);
    } on TimeoutException {
      throw const AppException(
        'The breed service took too long to respond.',
        kind: AppErrorKind.network,
      );
    } on SocketException {
      throw const AppException(
        'No internet connection.',
        kind: AppErrorKind.network,
      );
    } on http.ClientException catch (error) {
      throw AppException(
        'Could not reach the breed service. ${error.message}',
        kind: AppErrorKind.network,
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 400:
        // The server answers 400 with {"error":"Authorization header is
        // missing"} — a build configuration problem, not a user error.
        throw const AppException(
          'The breed service rejected the request. Check BREED_API_TOKEN in .env.',
          kind: AppErrorKind.apiAuth,
        );
      case 401:
      case 403:
        throw const AppException(
          'The breed API token is not valid.',
          kind: AppErrorKind.apiAuth,
        );
      case 404:
        throw const AppException(
          'The breed endpoint was not found. Check BREED_API_BREEDS_PATH in .env.',
          kind: AppErrorKind.apiAuth,
        );
      default:
        throw AppException(
          'The breed service returned an error (${response.statusCode}).',
          kind: AppErrorKind.network,
        );
    }

    final String body = JsonSanitizer.clean(utf8.decode(response.bodyBytes));
    try {
      return jsonDecode(body);
    } on FormatException {
      if (kDebugMode) {
        debugPrint('PawPedia: unparseable breed response from $uri');
      }
      throw const AppException(
        'The breed service sent something we could not read.',
        kind: AppErrorKind.parsing,
      );
    }
  }

  Uri _buildUri(Map<String, String> query) {
    final Uri base = Uri.parse(AppConfig.breedApiBaseUrl);
    final String path = AppConfig.breedApiBreedsPath;
    return base.replace(
      path: path.startsWith('/') ? path : '/$path',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  /// Normalises the several shapes a hand-written PHP endpoint might return:
  /// a bare array, or an object wrapping one under `data`, `breeds` or
  /// `result`, or a single object for a single row.
  static List<Map<String, dynamic>> _asRows(Object? decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((Map row) => row.cast<String, dynamic>())
          .toList();
    }
    if (decoded is Map) {
      final Map<String, dynamic> map = decoded.cast<String, dynamic>();
      for (final String key in const <String>['data', 'breeds', 'result', 'rows']) {
        final Object? nested = map[key];
        if (nested is List) return _asRows(nested);
      }
      // A single breed object.
      if (map.containsKey('breed_name') || map.containsKey('id')) {
        return <Map<String, dynamic>>[map];
      }
    }
    return const <Map<String, dynamic>>[];
  }
}
