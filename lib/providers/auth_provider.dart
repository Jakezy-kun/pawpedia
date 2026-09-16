import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../services/auth_service.dart';

/// Who is using the app right now.
enum AuthStatus {
  /// Still restoring the persisted session — show the splash, not Onboarding,
  /// so a logged-in user never sees a flash of the login screen on launch.
  unknown,

  /// No session and no guest choice yet: Onboarding / Login.
  signedOut,

  /// Browsing without an account. Breeds work; favourites are device-only.
  guest,

  signedIn,
}

/// Single source of truth for who is signed in, driven by
/// `supabase.auth.onAuthStateChange` so navigation reacts rather than polls.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _auth = authService ?? AuthService();

  static const String _guestKey = 'pawpedia.guest_mode';
  static const String _onboardedKey = 'pawpedia.onboarding_complete';

  final AuthService _auth;
  StreamSubscription<sb.AuthState>? _subscription;

  AuthStatus _status = AuthStatus.unknown;
  bool _hasSeenOnboarding = false;
  String? _lastSignUpEmail;

  AuthStatus get status => _status;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isGuest => _status == AuthStatus.guest;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// False when Supabase is not configured. The UI uses this to explain why
  /// account features are unavailable instead of failing on tap.
  bool get accountsAvailable => _auth.isAvailable;

  String? get userId => _auth.currentUser?.id;
  String? get email => _auth.currentEmail;
  String? get lastSignUpEmail => _lastSignUpEmail;

  /// Display name from auth metadata. Used only until the profile row loads.
  String get metadataName {
    final Object? name = _auth.currentUser?.userMetadata?['name'];
    final String text = name?.toString().trim() ?? '';
    return text.isEmpty ? 'PawPedia User' : text;
  }

  DateTime? get memberSince {
    final String? raw = _auth.currentUser?.createdAt;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> initialise() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _hasSeenOnboarding = prefs.getBool(_onboardedKey) ?? false;
    final bool wasGuest = prefs.getBool(_guestKey) ?? false;

    if (_auth.isAvailable) {
      // Re-evaluate on every auth event so sign-in, sign-out, token refresh and
      // expiry all move the app to the right place without imperative pushes.
      _subscription = _auth.onAuthStateChange.listen(
        (sb.AuthState state) => _applySession(state.session),
        onError: (Object error) {
          if (kDebugMode) debugPrint('PawPedia: auth stream error: $error');
        },
      );
    }

    final sb.Session? session = _auth.currentSession;
    if (session != null) {
      _set(AuthStatus.signedIn);
    } else {
      _set(wasGuest ? AuthStatus.guest : AuthStatus.signedOut);
    }
  }

  void _applySession(sb.Session? session) {
    if (session != null) {
      _persistGuest(false);
      _set(AuthStatus.signedIn);
      return;
    }
    // Signed out. Never silently drop someone into guest mode — that would
    // quietly swap their synced favourites for device-only ones.
    if (_status == AuthStatus.signedIn) _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus next) {
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<void> continueAsGuest() async {
    await _persistGuest(true);
    _set(AuthStatus.guest);
  }

  /// Leaves guest mode to show Login/Sign Up, without wiping the local
  /// favourites — the user may come straight back.
  Future<void> leaveGuest() async {
    await _persistGuest(false);
    _set(AuthStatus.signedOut);
  }

  Future<void> _persistGuest(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestKey, value);
  }

  // --- auth actions ---------------------------------------------------------

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signIn(email: email, password: password);
    // onAuthStateChange moves us to signedIn.
  }

  /// Returns true when the project requires email confirmation, in which case
  /// no session exists yet and the caller shows the "check your inbox" state.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final SignUpResult result =
        await _auth.signUp(name: name, email: email, password: password);
    if (result.needsEmailConfirmation) {
      _lastSignUpEmail = email.trim();
      notifyListeners();
    }
    return result.needsEmailConfirmation;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _persistGuest(false);
    _set(AuthStatus.signedOut);
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordReset(email);

  Future<void> updateEmail(String newEmail) => _auth.updateEmail(newEmail);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  Future<bool> verifyPassword(String password) => _auth.verifyPassword(password);

  /// Deletes the account server-side, then signs out locally.
  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    // The user no longer exists, so the local session is meaningless. Ignore
    // sign-out failures: the account is already gone either way.
    try {
      await _auth.signOut();
    } catch (_) {}
    await _persistGuest(false);
    _set(AuthStatus.signedOut);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
