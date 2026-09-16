/// A failure that already carries copy fit to show a user.
///
/// Services translate transport- and provider-specific errors into these at
/// their boundary, so no widget ever has to know what a `SocketException` or a
/// `PostgrestException` is.
class AppException implements Exception {
  const AppException(this.message, {this.kind = AppErrorKind.unknown});

  final String message;
  final AppErrorKind kind;

  @override
  String toString() => 'AppException($kind): $message';
}

enum AppErrorKind {
  /// No connectivity, DNS failure, or the request timed out.
  network,

  /// The breed API rejected our bearer token, or it is missing entirely.
  /// This is a build/config problem, not something the user can fix.
  apiAuth,

  /// The server answered, but not with something we could parse.
  parsing,

  /// Sign-in / sign-up / password problems. Message is user-facing.
  auth,

  /// Everything else.
  unknown,
}
