import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../errors/app_exception.dart';

/// Client for the Dog CEO API (https://dog.ceo/dog-api/), a free public API
/// of dog photos. No key, no account.
///
///   GET /breeds/list/all                 { "message": { breed: [sub, ...] } }
///   GET /breeds/image/random             { "message": "https://..." }
///   GET /breed/{path}/images/random/{n}  { "message": ["https://...", ...] }
///
/// Every response carries `"status": "success"` or `"error"`, and errors also
/// use a matching HTTP status. `{path}` is a breed, or a breed and sub-breed
/// such as `retriever/golden`.
class DogCeoClient {
  DogCeoClient({http.Client? httpClient, this.baseUrl = defaultBaseUrl})
      : _http = httpClient ?? http.Client();

  static const String defaultBaseUrl = 'https://dog.ceo/api';

  /// The API caps random multi-image requests at 50.
  static const int maxImages = 50;

  final http.Client _http;
  final String baseUrl;

  void dispose() => _http.close();

  /// Every breed Dog CEO knows, each with its sub-breeds (often none).
  Future<Map<String, List<String>>> fetchBreedList() async {
    final Object? message = await _get('breeds/list/all');
    if (message is! Map) throw _unexpected;
    return <String, List<String>>{
      for (final MapEntry<dynamic, dynamic> entry in message.entries)
        entry.key.toString(): entry.value is List
            ? (entry.value as List<dynamic>).map((Object? s) => '$s').toList()
            : const <String>[],
    };
  }

  /// One photo of any breed.
  Future<String> fetchRandomImage() async {
    final Object? message = await _get('breeds/image/random');
    if (message is! String || message.isEmpty) throw _unexpected;
    return message;
  }

  /// Up to [count] random photos of one breed, e.g. `retriever/golden`.
  Future<List<String>> fetchBreedImages(String path, {int count = 6}) async {
    final int n = count.clamp(1, maxImages);
    final Object? message = await _get('breed/$path/images/random/$n');
    if (message is! List) throw _unexpected;
    return message.whereType<String>().toList();
  }

  static const AppException _unexpected = AppException(
    'The dog photo service sent an unexpected response.',
    kind: AppErrorKind.parsing,
  );

  /// Returns the `message` member of a successful response.
  Future<Object?> _get(String path) async {
    final Uri uri = Uri.parse('$baseUrl/$path');

    late final http.Response response;
    try {
      response = await _http.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(AppDurations.networkTimeout);
    } on TimeoutException {
      throw const AppException(
        'The dog photo service took too long to respond.',
        kind: AppErrorKind.network,
      );
    } on SocketException {
      throw const AppException(
        'No internet connection.',
        kind: AppErrorKind.network,
      );
    } on http.ClientException {
      throw const AppException(
        'Could not reach the dog photo service.',
        kind: AppErrorKind.network,
      );
    }

    Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
    } on FormatException {
      body = null;
    }

    if (response.statusCode == 200 &&
        body is Map &&
        body['status'] == 'success') {
      return body['message'];
    }

    if (kDebugMode) {
      debugPrint('PawPedia: Dog CEO ${response.statusCode} for $uri');
    }
    throw response.statusCode == 404
        ? const AppException(
            'The dog photo service has no photos for that breed.',
            kind: AppErrorKind.network,
          )
        : const AppException(
            'The dog photo service is unavailable. Please try again.',
            kind: AppErrorKind.network,
          );
  }
}
