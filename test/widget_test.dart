import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mi_app/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('shows login screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('Ruta Facil El Alto'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
