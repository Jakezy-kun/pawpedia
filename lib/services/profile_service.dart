import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/error_mapper.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../models/profile.dart';

/// Reads and writes `public.profiles`, plus the avatar in Supabase Storage.
///
/// Every query here is scoped to the current user, and row-level security
/// enforces the same thing server-side — the client-side `.eq('id', userId)` is
/// for clarity and efficiency, not for safety.
class ProfileService {
  static const String _bucket = 'avatars';

  SupabaseClient get _client => SupabaseBootstrap.client;

  Future<Profile?> fetchProfile(String userId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Profile.fromJson(row);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Creates the profile row if the `handle_new_user` trigger has not been
  /// installed, so the app degrades to something usable instead of showing an
  /// empty profile forever.
  Future<Profile> ensureProfile({
    required String userId,
    required String fallbackName,
  }) async {
    final Profile? existing = await fetchProfile(userId);
    if (existing != null) return existing;

    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .insert(<String, dynamic>{'id': userId, 'name': fallbackName})
          .select()
          .single();
      return Profile.fromJson(row);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  Future<Profile> updateName({
    required String userId,
    required String name,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{'name': name.trim()})
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromJson(row);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  /// Uploads an avatar and returns its public URL.
  ///
  /// The path is `{userId}/avatar.jpg`; the storage policies require that first
  /// segment to equal the caller's uid, so one user cannot overwrite another's
  /// picture. A cache-busting query is appended because the object name never
  /// changes and `cached_network_image` would otherwise keep serving the old
  /// photo after an update.
  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    try {
      final String path = '$userId/avatar.jpg';
      await _client.storage.from(_bucket).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final String publicUrl = _client.storage.from(_bucket).getPublicUrl(path);
      return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  Future<Profile> setPhotoUrl({
    required String userId,
    required String? photoUrl,
  }) async {
    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(<String, dynamic>{'photo_url': photoUrl})
          .eq('id', userId)
          .select()
          .single();
      return Profile.fromJson(row);
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }

  Future<void> removeAvatar(String userId) async {
    try {
      await _client.storage.from(_bucket).remove(<String>['$userId/avatar.jpg']);
    } on StorageException {
      // Nothing to delete is a perfectly fine outcome here.
    } catch (error) {
      throw ErrorMapper.fromGenericError(error);
    }
  }
}
