import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Turns whatever Supabase throws into copy a person can act on.
///
/// Supabase's own messages are written for developers ("Invalid login
/// credentials", "AuthApiException(statusCode: 422)"). Showing those to a child
/// looking up dog breeds is not acceptable, so every path through auth funnels
/// through here.
abstract final class ErrorMapper {
  static AppException fromAuthError(Object error) {
    if (error is AppException) return error;

    if (error is AuthException) {
      final String raw = error.message.toLowerCase();

      if (raw.contains('invalid login credentials') ||
          raw.contains('invalid credentials')) {
        return const AppException(
          'Incorrect email or password',
          kind: AppErrorKind.auth,
        );
      }
      if (raw.contains('already registered') ||
          raw.contains('already been registered') ||
          raw.contains('user already exists')) {
        return const AppException(
          'That email is already registered',
          kind: AppErrorKind.auth,
        );
      }
      if (raw.contains('password should be at least') ||
          raw.contains('weak password') ||
          raw.contains('password is too short')) {
        return const AppException(
          'Password must be at least 8 characters',
          kind: AppErrorKind.auth,
        );
      }
      if (raw.contains('email not confirmed')) {
        return const AppException(
          'Please confirm your email first. Check your inbox for the link.',
          kind: AppErrorKind.auth,
        );
      }
      if (raw.contains('rate limit') || raw.contains('too many requests')) {
        return const AppException(
          'Too many attempts. Please wait a moment and try again.',
          kind: AppErrorKind.auth,
        );
      }
      if (raw.contains('should be different from the old password')) {
        return const AppException(
          'Your new password must be different from your current one.',
          kind: AppErrorKind.auth,
        );
      }
      return const AppException(
        'Something went wrong. Please try again.',
        kind: AppErrorKind.auth,
      );
    }

    return fromGenericError(error);
  }

  static AppException fromGenericError(Object error) {
    if (error is AppException) return error;

    if (error is SocketException || error is HttpException) {
      return const AppException(
        'No internet connection. Please check your network and try again.',
        kind: AppErrorKind.network,
      );
    }
    if (error is PostgrestException) {
      // Most commonly a row-level-security denial, which in a correctly built
      // app means the session expired rather than that the query was wrong.
      return const AppException(
        'We could not load your data. Please try again.',
        kind: AppErrorKind.unknown,
      );
    }
    if (error is StorageException) {
      return const AppException(
        'We could not upload that photo. Please try again.',
        kind: AppErrorKind.unknown,
      );
    }
    return const AppException(
      'Something went wrong. Please try again.',
      kind: AppErrorKind.unknown,
    );
  }
}
