import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/core/theme/app_theme.dart';
import 'package:pawpedia/providers/auth_provider.dart';
import 'package:pawpedia/screens/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The illustration bobs forever, so pumpAndSettle would never return. Step
// the clock over enough frames for any page turn or fade to finish instead.
Future<void> _advance(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<AuthProvider> _pump(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AuthProvider auth = AuthProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingScreen(),
        ),
      ),
    ),
  );
  await _advance(tester);
  return auth;
}

void main() {
  testWidgets('Next walks through all three slides', (WidgetTester tester) async {
    await _pump(tester);

    expect(find.text('Meet every good dog'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next'));
    await _advance(tester);
    expect(find.text('Search the way you think'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next'));
    await _advance(tester);
    expect(find.text('Keep a shortlist'), findsOneWidget);
    expect(find.bySemanticsLabel('Get Started'), findsOneWidget);
    expect(find.bySemanticsLabel('Slide 3 of 3'), findsOneWidget);
  });

  testWidgets('Get Started completes onboarding exactly once',
      (WidgetTester tester) async {
    final AuthProvider auth = await _pump(tester);
    int notifications = 0;
    auth.addListener(() => notifications++);

    for (int i = 0; i < 2; i++) {
      await tester.tap(find.bySemanticsLabel('Next'));
      await _advance(tester);
    }
    await tester.tap(find.bySemanticsLabel('Get Started'));
    // A second tap during the exit fade must not fire twice.
    await tester.tap(find.bySemanticsLabel('Get Started'), warnIfMissed: false);
    await _advance(tester);

    expect(auth.hasSeenOnboarding, isTrue);
    expect(notifications, 1);
  });

  testWidgets('Skip completes onboarding from the first slide',
      (WidgetTester tester) async {
    final AuthProvider auth = await _pump(tester);

    await tester.tap(find.text('Skip'));
    await _advance(tester);

    expect(auth.hasSeenOnboarding, isTrue);
  });

  testWidgets('swiping moves between slides', (WidgetTester tester) async {
    await _pump(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await _advance(tester);

    expect(find.bySemanticsLabel('Slide 2 of 3'), findsOneWidget);
  });

  testWidgets('survives the largest system text scale',
      (WidgetTester tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
