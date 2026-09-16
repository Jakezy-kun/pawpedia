import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawpedia/core/theme/app_theme.dart';
import 'package:pawpedia/models/breed.dart';
import 'package:pawpedia/widgets/breed_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

final Breed _breed = Breed.fromJson(<String, dynamic>{
  'id': 1,
  'breed_name': 'Golden Retriever',
  'breed_group': 'Sporting',
  'origin_country': 'Scotland',
  'average_lifespan': '10-12 years',
  'temperament': 'Friendly, Intelligent',
  'picture': '',
});

void main() {
  testWidgets('BreedListCard shows name, country and the first trait',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(BreedListCard(breed: _breed, onTap: () {})),
    );

    expect(find.text('Golden Retriever'), findsOneWidget);
    expect(find.text('Scotland'), findsOneWidget);
    expect(find.text('Friendly'), findsOneWidget);
  });

  testWidgets('BreedListCard survives the largest system text scale',
      (WidgetTester tester) async {
    // The layout has to bend rather than overflow when a user turns font size
    // all the way up, which is exactly where fixed-height rows break.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(
          SizedBox(
            width: 375,
            child: BreedListCard(breed: _breed, onTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Golden Retriever'), findsOneWidget);
  });

  testWidgets('tapping a breed card fires its callback',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _wrap(BreedListCard(breed: _breed, onTap: () => taps++)),
    );

    await tester.tap(find.text('Golden Retriever'));
    expect(taps, 1);
  });
}
