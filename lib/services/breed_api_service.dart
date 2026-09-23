import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/network/breed_api_client.dart';
import '../models/breed.dart';
import '../models/breed_draft.dart';

/// The app's source of breeds.
///
/// Reads from the live API when a token is configured, and from the bundled
/// seed file when one is not. That fallback is what makes every screen
/// reviewable on an emulator before any credentials exist — and it keeps the
/// UI work independent of a free-tier host that may be down.
class BreedApiService {
  BreedApiService({BreedApiClient? client})
      : _client = client ?? BreedApiClient();

  final BreedApiClient _client;

  /// True when breeds are coming from the bundled file rather than the server.
  /// Surfaced in the UI so a demo is never mistaken for live data.
  bool get isUsingSeedData => !AppConfig.hasBreedApi;

  Future<List<Breed>> fetchAllBreeds() async {
    if (isUsingSeedData) return _loadSeedBreeds();

    final List<Map<String, dynamic>> rows = await _client.fetchBreeds();
    final List<Breed> breeds = _parseRows(rows);
    if (breeds.isEmpty) {
      throw const AppException(
        'The breed service returned no breeds.',
        kind: AppErrorKind.parsing,
      );
    }
    return breeds;
  }

  /// Fresh detail for one breed.
  ///
  /// Returns null if the server has nothing for this id, or if we are running
  /// on seed data — in both cases the caller keeps showing the copy it already
  /// has rather than blanking the screen.
  Future<Breed?> fetchBreed(int id) async {
    if (isUsingSeedData) {
      final List<Breed> seed = await _loadSeedBreeds();
      for (final Breed breed in seed) {
        if (breed.id == id) return breed;
      }
      return null;
    }

    final Map<String, dynamic>? row = await _client.fetchBreed(id);
    return row == null ? null : Breed.fromJson(row);
  }

  /// Adds a breed and returns it as the server stored it.
  Future<Breed> createBreed(BreedDraft draft) async {
    _requireLiveApi();
    return _parseSaved(await _client.createBreed(draft.toJson()));
  }

  /// Saves every field of [draft] over breed [id].
  Future<Breed> updateBreed(int id, BreedDraft draft) async {
    _requireLiveApi();
    return _parseSaved(await _client.updateBreed(id, draft.toJson()));
  }

  Future<void> deleteBreed(int id) async {
    _requireLiveApi();
    await _client.deleteBreed(id);
  }

  void dispose() => _client.dispose();

  /// The seed file is bundled read-only data; there is nowhere to save to.
  /// The UI hides the write controls in this mode, so reaching here is a bug.
  void _requireLiveApi() {
    if (isUsingSeedData) {
      throw const AppException(
        'Adding, editing and deleting breeds needs the live catalogue. Add '
        'BREED_API_TOKEN to .env.',
        kind: AppErrorKind.apiAuth,
      );
    }
  }

  static Breed _parseSaved(Map<String, dynamic> row) {
    final Breed breed = Breed.fromJson(row);
    if (breed.id == 0) {
      throw const AppException(
        'The breed service sent an unexpected response.',
        kind: AppErrorKind.parsing,
      );
    }
    return breed;
  }

  // --- seed data -----------------------------------------------------------

  List<Breed>? _seedCache;

  Future<List<Breed>> _loadSeedBreeds() async {
    if (_seedCache != null) return _seedCache!;
    final String raw = await rootBundle.loadString('assets/seed/breeds.json');
    final Object? decoded = jsonDecode(raw);
    final List<Map<String, dynamic>> rows = (decoded as List<dynamic>)
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => row.cast<String, dynamic>())
        .toList();
    return _seedCache = _parseRows(rows);
  }

  /// Skips rows that cannot be parsed rather than failing the whole list: one
  /// malformed record in the database should not empty the Explore screen.
  static List<Breed> _parseRows(List<Map<String, dynamic>> rows) {
    final List<Breed> breeds = <Breed>[];
    for (final Map<String, dynamic> row in rows) {
      try {
        final Breed breed = Breed.fromJson(row);
        if (breed.id != 0) breeds.add(breed);
      } catch (error) {
        if (kDebugMode) debugPrint('PawPedia: skipped unparseable breed: $error');
      }
    }
    return breeds;
  }
}
