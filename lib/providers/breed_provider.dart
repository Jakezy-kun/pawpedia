import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_mapper.dart';
import '../models/breed.dart';
import '../services/breed_api_service.dart';

enum BreedLoadState { idle, loading, ready, error }

/// A breed group with how many breeds are in it, for the Explore chips.
@immutable
class GroupCount {
  const GroupCount(this.group, this.count);
  final String group;
  final int count;
}

/// Holds the breed catalogue and everything derived from it.
///
/// The whole list is fetched once and filtered in memory rather than issuing a
/// request per filter. That is the right call here for three reasons: the
/// Explore chips need counts across the entire catalogue anyway, a breeds
/// directory is a small static dataset, and the server's support for
/// `?search=`/`?group=`/`?country=` could not be verified — so relying on it
/// would make correctness depend on an unknown.
class BreedProvider extends ChangeNotifier {
  BreedProvider({BreedApiService? service})
      : _service = service ?? BreedApiService();

  final BreedApiService _service;

  BreedLoadState _state = BreedLoadState.idle;
  List<Breed> _breeds = <Breed>[];
  AppException? _error;

  BreedLoadState get state => _state;
  List<Breed> get breeds => List<Breed>.unmodifiable(_breeds);
  AppException? get error => _error;
  bool get isLoading => _state == BreedLoadState.loading;
  bool get hasError => _state == BreedLoadState.error;

  /// True when the catalogue came from the bundled seed file. Surfaced in the
  /// UI so demo data is never mistaken for the live database.
  bool get isUsingSeedData => _service.isUsingSeedData;

  Future<void> load({bool force = false}) async {
    if (_state == BreedLoadState.loading) return;
    if (_state == BreedLoadState.ready && !force) return;

    _state = BreedLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      _breeds = await _service.fetchAllBreeds();
      _state = BreedLoadState.ready;
    } catch (error) {
      _error = ErrorMapper.fromGenericError(error);
      _state = BreedLoadState.error;
    }
    notifyListeners();
  }

  Breed? byId(int id) {
    for (final Breed breed in _breeds) {
      if (breed.id == id) return breed;
    }
    return null;
  }

  /// Fresh detail for one breed, falling back to the cached copy when the
  /// request fails. A flaky network should not empty a screen the user can
  /// already see.
  Future<Breed?> refreshBreed(int id) async {
    try {
      final Breed? fresh = await _service.fetchBreed(id);
      if (fresh == null) return byId(id);
      final int index = _breeds.indexWhere((Breed b) => b.id == id);
      if (index >= 0) {
        _breeds = List<Breed>.from(_breeds)..[index] = fresh;
        notifyListeners();
      }
      return fresh;
    } catch (_) {
      return byId(id);
    }
  }

  // --- derived data ---------------------------------------------------------

  /// Groups in the canonical order from [kPreferredGroupOrder], with anything
  /// the database adds later appended alphabetically so a new group appears
  /// without a code change.
  List<GroupCount> get groupCounts {
    final Map<String, int> counts = <String, int>{};
    for (final Breed breed in _breeds) {
      counts[breed.group] = (counts[breed.group] ?? 0) + 1;
    }

    final List<String> known = kPreferredGroupOrder
        .where((String group) => counts.containsKey(group))
        .toList();
    final List<String> extra = counts.keys
        .where((String group) => !kPreferredGroupOrder.contains(group))
        .toList()
      ..sort();

    return <GroupCount>[
      for (final String group in <String>[...known, ...extra])
        GroupCount(group, counts[group]!),
    ];
  }

  List<String> get countries {
    final Set<String> unique = <String>{
      for (final Breed breed in _breeds) breed.originCountry,
    }..removeWhere((String country) => country.isEmpty);
    return unique.toList()..sort();
  }

  /// One breed chosen as the day's feature. Keyed on the date so it is stable
  /// for a whole day and does not reshuffle on every rebuild.
  Breed? get breedOfTheDay {
    if (_breeds.isEmpty) return null;
    final DateTime now = DateTime.now();
    final int dayNumber =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay;
    return _breeds[dayNumber % _breeds.length];
  }

  /// Filters the catalogue. Empty selections mean "no constraint", so the
  /// default call returns everything.
  List<Breed> filter({
    String query = '',
    Set<String> groups = const <String>{},
    Set<String> countries = const <String>{},
  }) {
    final String needle = query.trim().toLowerCase();
    return _breeds.where((Breed breed) {
      if (needle.isNotEmpty && !breed.name.toLowerCase().contains(needle)) {
        return false;
      }
      if (groups.isNotEmpty && !groups.contains(breed.group)) return false;
      if (countries.isNotEmpty && !countries.contains(breed.originCountry)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
