import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/core/network/json_sanitizer.dart';

void main() {
  group('JsonSanitizer', () {
    test('strips the comment the old PHP endpoint prepended to every response', () {
      // This is the exact shape the live host returns; without stripping it,
      // the first breed request fails with a FormatException whose message
      // gives no hint of the real cause.
      const String body = '/*  */[{"id":1,"breed_name":"Beagle"}]';

      final String cleaned = JsonSanitizer.clean(body);

      expect(cleaned, '[{"id":1,"breed_name":"Beagle"}]');
      expect(jsonDecode(cleaned), isA<List<dynamic>>());
    });

    test('strips a prefix ahead of a JSON object', () {
      const String body = '/*  */{"error":"Authorization header is missing"}';

      expect(
        jsonDecode(JsonSanitizer.clean(body)),
        <String, dynamic>{'error': 'Authorization header is missing'},
      );
    });

    test('leaves clean JSON untouched', () {
      const String body = '[{"id":1}]';
      expect(JsonSanitizer.clean(body), body);
    });

    test('drops trailing junk after the document', () {
      const String body = '[{"id":1}]<!-- injected footer -->';
      expect(jsonDecode(JsonSanitizer.clean(body)), <dynamic>[
        <String, dynamic>{'id': 1},
      ]);
    });

    test('handles leading whitespace and newlines', () {
      const String body = '\n\n  {"id":1}  \n';
      expect(jsonDecode(JsonSanitizer.clean(body)), <String, dynamic>{'id': 1});
    });

    test('passes non-JSON through so the real decode error still surfaces', () {
      // Masking this would turn "the host served an HTML error page" into a
      // silent empty list, which is much harder to diagnose.
      const String body = '<html><body>500 Internal Server Error</body></html>';
      expect(() => jsonDecode(JsonSanitizer.clean(body)), throwsFormatException);
    });

    test('handles an empty body', () {
      expect(JsonSanitizer.clean(''), '');
    });
  });
}
