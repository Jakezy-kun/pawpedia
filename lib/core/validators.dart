/// Form validation shared by Login, Sign Up, Edit Profile, Delete Account and
/// the Add / Edit Breed form, so the same rule is never written twice with two
/// different messages.
abstract final class Validators {
  /// Supabase enforces a minimum too, but validating here means the user finds
  /// out before a round trip rather than after one.
  static const int minPasswordLength = 8;

  // Deliberately permissive: the only authority on whether an address works is
  // whether the confirmation email arrives. This just catches typos.
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your name';
    if (text.length < 2) return 'That name looks a little short';
    return null;
  }

  static String? email(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your email';
    if (!_email.hasMatch(text)) return 'Please enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) return 'Please enter a password';
    if (text.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    return null;
  }

  /// For login, where an existing password just has to be present — telling
  /// someone their stored password is "too short" at sign-in is nonsense.
  static String? requiredPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Please enter your password';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your new password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  // --- breeds ---------------------------------------------------------------
  //
  // Lengths match the API's limits (server/src/BreedController.php), which in
  // turn match the MySQL columns, so the form catches what the server would
  // reject.

  static const int breedNameMax = 120;
  static const int breedGroupMax = 60;
  static const int originCountryMax = 80;
  static const int lifespanMax = 40;
  static const int temperamentMax = 255;
  static const int pictureMax = 500;

  static String? breedName(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter the breed name';
    if (text.length < 2) return 'That name looks a little short';
    return maxLength(breedNameMax)(text);
  }

  /// For optional fields: empty is fine, too long is not.
  static String? Function(String?) maxLength(int max) => (String? value) {
        final int length = value?.trim().length ?? 0;
        return length > max ? 'Keep this under $max characters' : null;
      };

  /// Optional; when present, a web address the app can actually load.
  static String? pictureUrl(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final Uri? uri = Uri.tryParse(text);
    final bool web = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!web) return 'Enter a full link starting with https://';
    return maxLength(pictureMax)(text);
  }
}
