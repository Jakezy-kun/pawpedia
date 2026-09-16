import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';

/// Initialises Supabase once, at startup.
///
/// Two deliberate choices:
///
///  * Only the anon key is ever passed. The service_role key exists solely in
///    the `delete-account` Edge Function's server-side environment, because
///    anything compiled into this app is readable by anyone who downloads it.
///  * `detectSessionInUri` is off. PawPedia uses email and password only — no
///    OAuth, no magic links — so there is no callback URL to intercept, and
///    leaving deep-link handling on would mean extra Android manifest and iOS
///    URL-scheme setup for a flow we never use.
abstract final class SupabaseBootstrap {
  static bool _initialised = false;

  /// True when Supabase is configured and ready. When false, the app still
  /// runs: browsing works and favourites fall back to on-device storage.
  static bool get isReady => _initialised;

  static Future<void> initialise() async {
    if (_initialised || !AppConfig.hasSupabase) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // Named `publishableKey` since supabase_flutter 2.16; it accepts both
        // the legacy `anon` JWT and the newer `sb_publishable_...` key, so the
        // .env variable stays SUPABASE_ANON_KEY to match what the Supabase
        // dashboard still calls it on existing projects.
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false,
        ),
      );
      _initialised = true;
    } catch (error) {
      // A bad URL or key must not take the whole app down at launch; the
      // account screens will report that sign-in is unavailable instead.
      if (kDebugMode) debugPrint('PawPedia: Supabase init failed: $error');
      _initialised = false;
    }
  }

  /// The shared client. Only call this after checking [isReady].
  static SupabaseClient get client => Supabase.instance.client;
}
