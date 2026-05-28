import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/features/routes/data/route_json_codec.dart';
import 'package:mi_app/features/routes/domain/models/transit_route.dart';

void main() {
  test('decodes bundled manual route export', () {
    final file = File(
      'assets/routes/ruta_facil_no_tiene_manual-1779730822843.json',
    );
    final json = jsonDecode(file.readAsStringSync());
    final route = const RouteJsonCodec().decodeRoute(
      (json as Map).cast<String, Object?>(),
    );

    expect(route.id, 'manual-1779730822843');
    expect(route.name, 'Ceja');
    expect(route.transportType, TransportType.minibus);
    expect(route.origin, 'UPEA');
    expect(route.destination, 'Ceja');
    expect(route.path.length, 157);
    expect(route.fareRules.single.fareBs, 2);
    expect(route.scheduleRules.single.activeDestination, 'Cerca a Ceja');
  });

  test('decodes bundled 204 route export with empty syndicate', () {
    final file = File('assets/routes/ruta_facil_204_manual-1779759085763.json');
    final json = jsonDecode(file.readAsStringSync());
    final route = const RouteJsonCodec().decodeRoute(
      (json as Map).cast<String, Object?>(),
    );

    expect(route.id, 'manual-1779759085763');
    expect(route.line, '204');
    expect(route.syndicate, '');
    expect(route.origin, 'Ballivian');
    expect(route.destination, 'Parada 204');
    expect(route.path.length, 102);
    expect(
      route.scheduleRules.single.activeDestination,
      'Antes del puente Chino',
    );
  });
}
