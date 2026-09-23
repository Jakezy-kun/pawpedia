import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/core/theme/app_theme.dart';
import 'package:pawpedia/providers/auth_provider.dart';
import 'package:pawpedia/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

/// The text field under a given label, e.g. 'Email'.
EditableText _field(WidgetTester tester, String label) {
  final Finder column = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  return tester.widget<EditableText>(
    find.descendant(of: column.first, matching: find.byType(EditableText)),
  );
}

void main() {
  testWidgets('switching to Sign up leaves the email field visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );

    expect(_field(tester, 'Email').obscureText, isFalse);
    expect(_field(tester, 'Password').obscureText, isTrue);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(_field(tester, 'Name').obscureText, isFalse);
    expect(_field(tester, 'Email').obscureText, isFalse);
    expect(_field(tester, 'Password').obscureText, isTrue);
  });
}
