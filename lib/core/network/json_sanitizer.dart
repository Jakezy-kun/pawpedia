/// Trims a response body back to the JSON document inside it.
///
/// The original `dogbreeds.php` endpoint began every response with `/*  */` —
/// most likely text sitting outside the `<?php` tag in an included file — and
/// `jsonDecode` throws on that. The REST API in `server/` discards stray output
/// before responding, so this is now a guard rather than a requirement: a host
/// that starts prepending output again degrades to working, not to a
/// FormatException that points nowhere near the cause.
abstract final class JsonSanitizer {
  /// Returns [body] from its first `{` or `[` through to the matching final
  /// `}` or `]`, discarding whatever the host wrapped around it.
  ///
  /// Input that is already clean JSON passes through unchanged. Input with no
  /// JSON in it at all is returned trimmed, so the caller's `jsonDecode` still
  /// throws and the real error surfaces instead of being masked here.
  static String clean(String body) {
    final int start = _firstJsonStart(body);
    if (start < 0) return body.trim();

    final int end = _lastJsonEnd(body, start);
    if (end <= start) return body.substring(start).trim();

    return body.substring(start, end + 1).trim();
  }

  static int _firstJsonStart(String body) {
    for (int i = 0; i < body.length; i++) {
      final String c = body[i];
      if (c == '{' || c == '[') return i;
    }
    return -1;
  }

  static int _lastJsonEnd(String body, int start) {
    // The document opens with `{` or `[`; its matching close is the last
    // occurrence of the corresponding bracket.
    final String closer = body[start] == '{' ? '}' : ']';
    for (int i = body.length - 1; i > start; i--) {
      if (body[i] == closer) return i;
    }
    return -1;
  }
}
