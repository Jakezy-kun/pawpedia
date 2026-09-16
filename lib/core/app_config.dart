import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration, loaded once from `.env` at startup.
///
/// Deliberately tolerant: a missing or half-filled `.env` must not crash the
/// app. Instead the two subsystems degrade independently —
///   * no breed API token  -> breeds come from the bundled seed file
///   * no Supabase keys    -> accounts are unavailable, guest mode still works
/// which is what makes the UI reviewable before any credentials exist.
abstract final class AppConfig {
  static bool _loaded = false;

  /// False when `.env` could not be read. Every lookup then returns its
  /// fallback, because `dotenv` throws `NotInitializedError` rather than
  /// returning null once loading has failed.
  static bool _available = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _available = true;
    } catch (_) {
      // No .env bundled (or malformed). Everything falls back to defaults and
      // the app runs in seed + guest mode.
      if (kDebugMode) {
        debugPrint(
          'PawPedia: no .env found. Running with bundled seed breeds and '
          'accounts disabled. Copy .env.example to .env to change that.',
        );
      }
    }
    _loaded = true;
  }

  static String _read(String key, {String fallback = ''}) {
    if (!_available) return fallback;
    final value = dotenv.maybeGet(key)?.trim();
    return (value == null || value.isEmpty) ? fallback : value;
  }

  // --- Supabase ------------------------------------------------------------
  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');

  /// True once both Supabase values are present. When false the app hides
  /// account features rather than throwing on every auth call.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // --- Breed API -----------------------------------------------------------
  //
  // Defaults reflect the server as it actually behaves, which is not what the
  // original brief described. See README "Breed API reality check":
  //   * port 443 does not answer, so the scheme is http
  //   * there is no /api prefix; the endpoint is /dogbreeds.php
  static String get breedApiBaseUrl =>
      _read('BREED_API_BASE_URL', fallback: 'http://dogbreeds.mooo.com');

  static String get breedApiBreedsPath =>
      _read('BREED_API_BREEDS_PATH', fallback: '/dogbreeds.php');

  static String get breedApiToken => _read('BREED_API_TOKEN');

  /// Without a token every request comes back 401, so there is no point
  /// hitting the network at all — the seed data is used instead.
  static bool get hasBreedApi => breedApiToken.isNotEmpty;
}
