import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdict/features/flash_cards/result_screen.dart';

void main() {
  group('ResultScreen Tests', () {
    testWidgets('ResultScreen displays correct score and percentage', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResultScreen(score: 7, total: 10, peekCount: 2),
      ));

      expect(find.text('7'), findsOneWidget);
      expect(find.text('out of 10'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('Great job! Keep it up!'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // sneak peeks
    });

    testWidgets('ResultScreen displays orange color for 40-70%', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResultScreen(score: 5, total: 10, peekCount: 0),
      ));

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Not bad! Practice makes perfect.'), findsOneWidget);
    });

    testWidgets('ResultScreen displays red color for <40%', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResultScreen(score: 2, total: 10, peekCount: 0),
      ));

      expect(find.text('20%'), findsOneWidget);
      expect(find.text('Keep practicing — you\'ll get better!'), findsOneWidget);
    });
  });
}
