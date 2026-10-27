import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bethel_open_bible_church/main.dart';

void main() {
  testWidgets('home loads with Bethel branding and no native app bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BethelApp());
    await tester.pumpAndSettle();
    expect(find.text('B E T H E L'), findsOneWidget);
    expect(find.text('WELCOME HOME'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Word and prayer tabs navigate', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BethelApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word'));
    await tester.pumpAndSettle();
    expect(find.text('A word for today.'), findsOneWidget);
    await tester.tap(find.text('Prayer'));
    await tester.pumpAndSettle();
    expect(find.text('You are not alone.'), findsOneWidget);
  });
}
