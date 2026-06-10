import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/app/app_settings.dart';
import 'package:mi_app/app/ruta_facil_app.dart';
import 'package:mi_app/features/home/presentation/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _buildHome({required bool collectorMode}) async {
  SharedPreferences.setMockInitialValues({'collector_mode': collectorMode});
  final settings = await AppSettings.load();
  return AppSettingsScope(
    settings: settings,
    child: const MaterialApp(home: HomePage()),
  );
}

void main() {
  testWidgets('shows collector home screen', (tester) async {
    await tester.pumpWidget(await _buildHome(collectorMode: true));

    expect(find.text('Ruta Fácil'), findsOneWidget);
    expect(find.text('Grabar ruta'), findsWidgets);
    expect(find.text('Rutas favoritas'), findsNothing);
  });

  testWidgets('shows passenger home screen', (tester) async {
    await tester.pumpWidget(await _buildHome(collectorMode: false));

    expect(find.text('Ruta Fácil'), findsOneWidget);
    expect(find.text('Rutas favoritas'), findsWidgets);
    expect(find.text('Grabar ruta'), findsNothing);
  });
}
