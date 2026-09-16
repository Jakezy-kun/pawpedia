import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_mapper.dart';
import '../core/supabase/supabase_bootstrap.dart';

/// Result of a sign-up, which is not always "you are now logged in".
///
/// If the Supabase project has email confirmation switched on, `signUp`
/// succeeds but returns no session — the user has to click a link first. The
/// UI has to tell them that rather than silently doing nothing.
class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

/// Every Supabase Auth call the app makes, with developer-facing errors
/// translated at the boundary.
class AuthService {
  SupabaseClient get _client => SupabaseBootstrap.client;

  bool get isAvailable => SupabaseBootstrap.isReady;

  Session? get currentSession =>
      isAvailable ? _client.auth.currentSession : null;

  User? get currentUser => isAvailable ? _client.auth.currentUser : null;

  String? get currentEmail => currentUser?.email;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  void _requireAvailable() {
    if (!isAvailable) {
      throw const AppException(
        'Accounts are unavailable. Add SUPABASE_URL and SUPABASE_ANON_KEY to '
        '.env, then restart the app.',
        kind: AppErrorKind.auth,
      );
    }
  }

  // --- CREATE --------------------------------------------------------------

  /// The display name rides along in user metadata, where the
  /// `handle_new_user` trigger picks it up to seed `public.profiles.name`.
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _requireAvailable();
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'name': name.trim()},
      );
      return SignUpResult(needsEmailConfirmation: response.session == null);
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  // --- READ ----------------------------------------------------------------

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _requireAvailable();
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    _requireAvailable();
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  // --- UPDATE --------------------------------------------------------------

  /// Starts an email change. This does NOT take effect immediately: Supabase
  /// mails a confirmation link to the new address and the old one stays active
  /// until it is clicked. Callers must say so in the UI.
  Future<void> updateEmail(String newEmail) async {
    _requireAvailable();
    try {
      await _client.auth.updateUser(UserAttributes(email: newEmail.trim()));
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  /// Changes the password, verifying the current one first.
  ///
  /// `updateUser(password:)` on its own will happily change the password of
  /// anyone holding a live session without asking what the old one was. On a
  /// shared or unlocked phone that is an account takeover, so we re-verify by
  /// signing in with the password the user just typed and only proceed if that
  /// succeeds.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _requireAvailable();
    final String? email = currentEmail;
    if (email == null) {
      throw const AppException(
        'You need to be logged in to change your password.',
        kind: AppErrorKind.auth,
      );
    }

    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } catch (_) {
      throw const AppException(
        'Current password is incorrect.',
        kind: AppErrorKind.auth,
      );
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw ErrorMapper.fromAuthError(error);
    }
  }

  /// Confirms the password belongs to the signed-in user, without changing
  /// anything. Used to gate account deletion.
  Future<bool> verifyPassword(String password) async {
    _requireAvailable();
    final String? email = currentEmail;
    if (email == null) return false;
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- DELETE --------------------------------------------------------------

  /// Deletes the account through the `delete-account` Edge Function.
  ///
  /// The client cannot do this itself: `auth.admin.deleteUser` needs the
  /// service_role key, which must never ship in an app bundle. The function
  /// verifies the caller's own JWT and deletes only that user; `profiles` and
  /// `favorites` then cascade.
  Future<void> deleteAccount() async {
    _requireAvailable();
    try {
      final FunctionResponse response =
          await _client.functions.invoke('delete-account');
      if (response.status != 200) {
        final Object? data = response.data;
        final String? message =
            data is Map && data['error'] is String ? data['error'] as String : null;
        throw AppException(
          message ?? 'We could not delete your account. Please try again.',
          kind: AppErrorKind.unknown,
        );
      }
    } on AppException {
      rethrow;
    } on FunctionException catch (error) {
      final Object? details = error.details;
      final String? message = details is Map && details['error'] is String
          ? details['error'] as String
          : null;
      throw AppException(
        message ??
            'Account deletion is not set up yet. Deploy the delete-account '
            'Edge Function and try again.',
        kind: AppErrorKind.unknown,
      );
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }
}
