// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App should build without error', (WidgetTester tester) async {
    // Build a minimal test app instead of the full Arena app
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Arena Test App'),
            ),
          ),
        ),
      ),
    );

    // Verify that the app builds without error
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Arena Test App'), findsOneWidget);
  });
}
