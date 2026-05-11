import 'package:flutter/material.dart';

import 'app/app_settings.dart';
import 'app/ruta_facil_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(RutaFacilApp(settings: settings));
}
