import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mi_app/features/home/presentation/home_page.dart';

void main() {
  testWidgets('shows collector home screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('Ruta Facil El Alto'), findsOneWidget);
    expect(find.text('Grabar ruta'), findsWidgets);
  });
}
