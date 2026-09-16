import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/profile_service.dart';

/// The signed-in user's `public.profiles` row.
///
/// Guests have no profile; the screens that would show one offer a
/// create-account prompt instead, so this provider simply stays empty.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({ProfileService? service})
      : _service = service ?? ProfileService();

  final ProfileService _service;

  String? _userId;
  Profile? _profile;
  bool _loading = false;

  Profile? get profile => _profile;
  bool get isLoading => _loading;

  /// The name to greet the user with, before or without a loaded profile.
  String displayName({String fallback = 'there'}) {
    final String? name = _profile?.name.trim();
    if (name == null || name.isEmpty) return fallback;
    // Greetings read better with a first name only.
    return name.split(RegExp(r'\s+')).first;
  }

  /// Called from `ChangeNotifierProxyProvider.update`, which runs during build
  /// — so the notify is deferred to a microtask rather than fired synchronously,
  /// which would throw "setState() called during build".
  void syncWithAuth({
    required String? userId,
    required String fallbackName,
  }) {
    if (_userId == userId) return;
    _userId = userId;
    _profile = null;

    Future<void>.microtask(() async {
      notifyListeners();
      if (userId != null) await load(fallbackName: fallbackName);
    });
  }

  Future<void> load({String fallbackName = 'PawPedia User'}) async {
    final String? userId = _userId;
    if (userId == null) return;

    _loading = true;
    notifyListeners();
    try {
      _profile = await _service.ensureProfile(
        userId: userId,
        fallbackName: fallbackName,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('PawPedia: profile load failed: $error');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final String? userId = _userId;
    if (userId == null) return;
    _profile = await _service.updateName(userId: userId, name: name);
    notifyListeners();
  }

  Future<void> updateAvatar(File file) async {
    final String? userId = _userId;
    if (userId == null) return;
    final String url = await _service.uploadAvatar(userId: userId, file: file);
    _profile = await _service.setPhotoUrl(userId: userId, photoUrl: url);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    final String? userId = _userId;
    if (userId == null) return;
    await _service.removeAvatar(userId);
    _profile = await _service.setPhotoUrl(userId: userId, photoUrl: null);
    notifyListeners();
  }

  void clear() {
    _userId = null;
    _profile = null;
    notifyListeners();
  }
}
