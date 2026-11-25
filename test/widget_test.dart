import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('entorno de widgets de Sinchi funciona', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Sinchi'))),
    );

    expect(find.text('Sinchi'), findsOneWidget);
  });
}
