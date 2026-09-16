import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/breed.dart';

/// Backs the three tiles on Profile: breeds viewed, and groups explored.
///
/// These are genuinely counted from what the user has opened rather than
/// invented, and kept on the device — they are a bit of delight, not data worth
/// a table and a round trip. Sets (not counters) are stored so that opening the
/// same breed twice does not inflate the number.
class StatsProvider extends ChangeNotifier {
  static const String _viewedKey = 'pawpedia.viewed_breed_ids';
  static const String _groupsKey = 'pawpedia.viewed_groups';

  Set<int> _viewedBreedIds = <int>{};
  Set<String> _viewedGroups = <String>{};

  int get breedsViewed => _viewedBreedIds.length;
  int get groupsExplored => _viewedGroups.length;

  Future<void> initialise() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _viewedBreedIds = (prefs.getStringList(_viewedKey) ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    _viewedGroups = (prefs.getStringList(_groupsKey) ?? <String>[]).toSet();
    notifyListeners();
  }

  /// Called when a breed detail screen opens.
  Future<void> recordView(Breed breed) async {
    final bool isNewBreed = _viewedBreedIds.add(breed.id);
    final bool isNewGroup =
        breed.group.isNotEmpty && _viewedGroups.add(breed.group);
    if (!isNewBreed && !isNewGroup) return;

    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _viewedKey,
      _viewedBreedIds.map((int id) => id.toString()).toList(),
    );
    await prefs.setStringList(_groupsKey, _viewedGroups.toList());
  }

  Future<void> reset() async {
    _viewedBreedIds = <int>{};
    _viewedGroups = <String>{};
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_viewedKey);
    await prefs.remove(_groupsKey);
  }
}
