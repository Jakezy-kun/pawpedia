/// Values that are referenced from more than one screen and would otherwise be
/// duplicated string literals.
abstract final class AppStrings {
  static const String appName = 'PawPedia';
  static const String guestEmail = 'Browsing as a guest';

  /// Shown wherever guest-mode favourites are surfaced. Guests get real
  /// favourites, but they live in SharedPreferences on this handset only.
  static const String guestFavoritesNotice =
      'Favorites are saved on this device only. Create an account to keep them '
      'and sync across devices.';
}

abstract final class AppDurations {
  /// How long to wait after the last keystroke before searching.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Window in which an accidental favourite removal can be undone.
  static const Duration undoWindow = Duration(seconds: 5);

  static const Duration networkTimeout = Duration(seconds: 15);
}

/// Canonical ordering for breed-group chips. Groups returned by the API that
/// are not in this list are appended alphabetically, so a new group added to
/// the database still shows up without a code change.
const List<String> kPreferredGroupOrder = <String>[
  'Sporting',
  'Herding',
  'Toy',
  'Working',
  'Hound',
  'Non-Sporting',
];
