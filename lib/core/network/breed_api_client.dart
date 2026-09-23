import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../constants.dart';
import '../errors/app_exception.dart';
import 'json_sanitizer.dart';

/// Client for the PawPedia breed REST API (see `server/`).
///
///   GET    {base}/breeds        paginated collection: { data, meta, links }
///   GET    {base}/breeds/{id}   one breed:            { data, links }
///   POST   {base}/breeds        create -> 201         { data, links }
///   PUT    {base}/breeds/{id}   replace -> 200        { data, links }
///   DELETE {base}/breeds/{id}   remove -> 204         (no body)
///
/// Errors arrive as `{ "error": { "status", "code", "message" } }` with a
/// matching HTTP status, so the status code alone decides how a failure is
/// handled.
class BreedApiClient {
  BreedApiClient({
    http.Client? httpClient,
    String? baseUrl,
    String? token,
    this.pageSize = maxPageSize,
  })  : assert(pageSize > 0 && pageSize <= maxPageSize),
        _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.breedApiBaseUrl,
        _token = token ?? AppConfig.breedApiToken;

  final http.Client _http;
  final String _baseUrl;
  final String _token;

  /// Largest page the server allows, and the default: the fewest round trips
  /// for the whole catalogue.
  static const int maxPageSize = 100;

  /// Rows requested per page. Only tests use anything other than the maximum.
  final int pageSize;

  /// Guards against a server that keeps returning a `next` link forever.
  static const int maxPages = 50;

  void dispose() => _http.close();

  /// Every breed, following the collection's `links.next` until it runs out.
  Future<List<Map<String, dynamic>>> fetchBreeds() async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    final Set<Uri> visited = <Uri>{};

    Uri? next = _resource('breeds').replace(
      queryParameters: <String, String>{'per_page': '$pageSize'},
    );

    while (next != null) {
      if (!visited.add(next) || visited.length > maxPages) {
        throw const AppException(
          'The breed service returned an endless list of pages.',
          kind: AppErrorKind.parsing,
        );
      }

      final Object? body = await _get(next);
      rows.addAll(_asRowList(body));
      next = _nextLink(body, current: next);
    }

    return rows;
  }

  /// One breed, or null when the API answers 404 for this id — the caller
  /// keeps showing the copy it already has.
  Future<Map<String, dynamic>?> fetchBreed(int id) async {
    try {
      final Object? body = await _get(_resource('breeds/$id'));
      final Object? data = body is Map ? body['data'] : null;
      return data is Map ? data.cast<String, dynamic>() : null;
    } on _NotFound {
      return null;
    }
  }

  /// Creates a breed and returns it as stored, including its new id.
  ///
  /// [fields] uses the API's names (`breed_name`, `breed_group`, ...).
  Future<Map<String, dynamic>> createBreed(Map<String, dynamic> fields) async {
    final Object? body = await _send('POST', _resource('breeds'), json: fields);
    return _asRow(body);
  }

  /// Replaces every field of one breed and returns it as stored.
  Future<Map<String, dynamic>> updateBreed(
    int id,
    Map<String, dynamic> fields,
  ) async {
    try {
      final Object? body =
          await _send('PUT', _resource('breeds/$id'), json: fields);
      return _asRow(body);
    } on _NotFound {
      throw const AppException(
        'This breed no longer exists. Pull down on Explore to refresh.',
        kind: AppErrorKind.validation,
      );
    }
  }

  /// Deletes one breed. A 404 counts as success: the breed is gone either way,
  /// which is all the caller asked for.
  Future<void> deleteBreed(int id) async {
    try {
      await _send('DELETE', _resource('breeds/$id'));
    } on _NotFound {
      return;
    }
  }

  /// `{base}/{path}`, keeping any path the base URL already has (`/api`).
  Uri _resource(String path) {
    final Uri base = Uri.parse(_baseUrl);
    final String basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    return base.replace(path: '$basePath/$path', query: null);
  }

  /// Resolves `links.next` against the page it came from.
  ///
  /// Refuses a link that points at a different host, scheme or port: following
  /// it would hand the bearer token to whoever that host is.
  Uri? _nextLink(Object? body, {required Uri current}) {
    final Object? links = body is Map ? body['links'] : null;
    final Object? next = links is Map ? links['next'] : null;
    if (next is! String || next.isEmpty) return null;

    final Uri resolved = current.resolve(next);
    if (resolved.scheme != current.scheme ||
        resolved.host != current.host ||
        resolved.port != current.port) {
      throw const AppException(
        'The breed service returned a link to another server.',
        kind: AppErrorKind.parsing,
      );
    }
    return resolved;
  }

  Future<Object?> _get(Uri uri) => _send('GET', uri);

  /// One request. Returns the decoded body of a 2xx answer (null for 204) and
  /// turns every other status into an [AppException].
  Future<Object?> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? json,
  }) async {
    if (_token.isEmpty) {
      throw const AppException(
        'The breed API token is missing from .env.',
        kind: AppErrorKind.apiAuth,
      );
    }

    final http.Request request = http.Request(method, uri)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });
    if (json != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(json);
    }

    late final http.Response response;
    try {
      response = await _http
          .send(request)
          .then(http.Response.fromStream)
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
    } on http.ClientException {
      throw const AppException(
        'Could not reach the breed service.',
        kind: AppErrorKind.network,
      );
    }

    final Object? body = _decode(response, uri);

    if (_isSuccess(response.statusCode)) return body;

    if (kDebugMode) {
      debugPrint('PawPedia: breed API ${response.statusCode} for $uri: '
          '${_errorCode(body) ?? 'no error code'}');
    }

    switch (response.statusCode) {
      case 401:
        throw const AppException(
          'The breed API token is not valid. Check BREED_API_TOKEN in .env.',
          kind: AppErrorKind.apiAuth,
        );
      case 403:
        throw const AppException(
          'The breed service requires HTTPS. Use https:// in BREED_API_BASE_URL.',
          kind: AppErrorKind.apiAuth,
        );
      case 404:
        // A missing breed is a normal outcome; a missing route is a
        // configuration mistake.
        if (_errorCode(body) == 'breed_not_found') throw const _NotFound();
        throw const AppException(
          'The breed API was not found. Check BREED_API_BASE_URL in .env.',
          kind: AppErrorKind.apiAuth,
        );
      case 400:
        throw const AppException(
          'The breed service rejected the request.',
          kind: AppErrorKind.parsing,
        );
      case 405:
        throw const AppException(
          'The breed service does not accept changes yet. Upload the latest '
          'server/ files to the host.',
          kind: AppErrorKind.apiAuth,
        );
      case 409:
        final String message =
            _errorMessage(body) ?? 'A breed with that name already exists.';
        // The only conflict the API reports is a duplicate name.
        throw AppException(
          message,
          kind: AppErrorKind.validation,
          fieldErrors: <String, String>{'breed_name': message},
        );
      case 413:
        throw const AppException(
          'That is too much text to save. Please shorten it.',
          kind: AppErrorKind.validation,
        );
      case 422:
        final Map<String, String> fields = _fieldErrors(body);
        // "_" is a failure no single field owns, e.g. a column narrower than
        // the API expected.
        throw AppException(
          fields['_'] ?? 'Please fix the highlighted fields.',
          kind: AppErrorKind.validation,
          fieldErrors: fields,
        );
      case 503:
        throw const AppException(
          'The breed service is temporarily unavailable. Please try again.',
          kind: AppErrorKind.network,
        );
      default:
        throw AppException(
          'The breed service returned an error (${response.statusCode}).',
          kind: AppErrorKind.network,
        );
    }
  }

  Object? _decode(http.Response response, Uri uri) {
    final String text = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (text.trim().isEmpty) return null;
    try {
      // The REST API sends clean JSON. Sanitising is kept as a guard against a
      // misconfigured host prepending output, which the old endpoint did.
      return jsonDecode(JsonSanitizer.clean(text));
    } on FormatException {
      if (!_isSuccess(response.statusCode)) return null;
      if (kDebugMode) debugPrint('PawPedia: unparseable breed response from $uri');
      throw const AppException(
        'The breed service sent something we could not read.',
        kind: AppErrorKind.parsing,
      );
    }
  }

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  static String? _errorCode(Object? body) {
    final Object? error = body is Map ? body['error'] : null;
    final Object? code = error is Map ? error['code'] : null;
    return code is String ? code : null;
  }

  static String? _errorMessage(Object? body) {
    final Object? error = body is Map ? body['error'] : null;
    final Object? message = error is Map ? error['message'] : null;
    return message is String && message.isNotEmpty ? message : null;
  }

  static Map<String, String> _fieldErrors(Object? body) {
    final Object? error = body is Map ? body['error'] : null;
    final Object? fields = error is Map ? error['fields'] : null;
    if (fields is! Map) return const <String, String>{};
    return <String, String>{
      for (final MapEntry<dynamic, dynamic> entry in fields.entries)
        if (entry.value is String) entry.key.toString(): entry.value as String,
    };
  }

  static Map<String, dynamic> _asRow(Object? body) {
    final Object? data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw const AppException(
        'The breed service sent an unexpected response.',
        kind: AppErrorKind.parsing,
      );
    }
    return data.cast<String, dynamic>();
  }

  static List<Map<String, dynamic>> _asRowList(Object? body) {
    final Object? data = body is Map ? body['data'] : null;
    if (data is! List) {
      throw const AppException(
        'The breed service sent an unexpected response.',
        kind: AppErrorKind.parsing,
      );
    }
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => row.cast<String, dynamic>())
        .toList();
  }
}

class _NotFound implements Exception {
  const _NotFound();
}
