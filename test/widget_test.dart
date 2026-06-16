import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sorta_frontend/main.dart';

void main() {
  testWidgets('App opens empty screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SortaApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
