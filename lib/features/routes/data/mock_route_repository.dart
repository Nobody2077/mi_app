import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/bus_position.dart';
import '../domain/models/route_report.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';

class MockRouteRepository implements RouteRepository {
  const MockRouteRepository();

  static final List<TransitRoute> _routes = [
    TransitRoute(
      id: 'ceja-villa-adela',
      name: 'Linea 101 - Ceja a Villa Adela',
      transportType: TransportType.minibus,
      syndicate: 'Sindicato 16 de Julio',
      line: '101',
      origin: 'Ceja El Alto',
      destination: 'Villa Adela',
      fareBs: 2,
      serviceHours: '06:00 - 22:00',
      description: 'Ruta demo con puntos de control manuales por avenidas.',
      averageSpeedKmh: AppConstants.defaultAverageSpeedKmh,
      stops: const ['Ceja', 'Cruce Viacha', '16 de Julio', 'Villa Adela'],
      path: const [
        LatLng(-16.50040, -68.16310),
        LatLng(-16.50620, -68.16350),
        LatLng(-16.51280, -68.16390),
        LatLng(-16.52040, -68.16450),
        LatLng(-16.52820, -68.16530),
        LatLng(-16.53520, -68.16620),
      ],
    ),
    TransitRoute(
      id: 'ceja-senkata',
      name: 'Trufi 42 - Ceja a Senkata',
      transportType: TransportType.trufi,
      syndicate: 'Sindicato Senkata',
      line: '42',
      origin: 'Ceja El Alto',
      destination: 'Senkata',
      fareBs: 2.5,
      serviceHours: '05:30 - 21:30',
      description: 'Servicio rapido hacia el sector Senkata.',
      averageSpeedKmh: 20,
      stops: const ['Ceja', 'Av. 6 de Marzo', 'Puente Vela', 'Senkata'],
      path: const [
        LatLng(-16.50040, -68.16310),
        LatLng(-16.50750, -68.16520),
        LatLng(-16.51640, -68.16780),
        LatLng(-16.52630, -68.17090),
        LatLng(-16.53680, -68.17430),
        LatLng(-16.54820, -68.17800),
      ],
    ),
    TransitRoute(
      id: 'ceja-rio-seco',
      name: 'Micro A - Ceja a Rio Seco',
      transportType: TransportType.micro,
      syndicate: 'Cooperativa Rio Seco',
      line: 'A',
      origin: 'Ceja El Alto',
      destination: 'Rio Seco',
      fareBs: 1.5,
      serviceHours: '06:00 - 20:30',
      description: 'Ruta troncal de prueba hacia Rio Seco.',
      averageSpeedKmh: 17,
      stops: const ['Ceja', '16 de Julio', 'Ballivian', 'Rio Seco'],
      path: const [
        LatLng(-16.50040, -68.16310),
        LatLng(-16.49640, -68.16830),
        LatLng(-16.49120, -68.17390),
        LatLng(-16.48620, -68.17960),
        LatLng(-16.48040, -68.18620),
        LatLng(-16.47420, -68.19360),
      ],
    ),
    TransitRoute(
      id: 'piloto-casa-u',
      name: 'Piloto Casa - Universidad',
      transportType: TransportType.minibus,
      syndicate: 'Ruta manual de prueba',
      line: 'Demo',
      origin: 'Zona 16 de Julio',
      destination: 'Universidad UPEA',
      fareBs: 2,
      serviceHours: 'Ruta de prueba',
      description:
          'Reemplaza estos puntos por tu casa, esquinas importantes y la U.',
      averageSpeedKmh: 18,
      stops: const ['Casa', 'Av. Juan Pablo II', 'Villa Esperanza', 'UPEA'],
      path: const [
        LatLng(-16.50460, -68.17080),
        LatLng(-16.50180, -68.17640),
        LatLng(-16.49860, -68.18320),
        LatLng(-16.49520, -68.19040),
        LatLng(-16.49280, -68.19560),
      ],
    ),
    TransitRoute(
      id: 'linea-204-ballivian-ceja',
      name: 'Linea 204 - Gral. Camacho a Av. 6 de Marzo',
      transportType: TransportType.minibus,
      syndicate: 'Linea 204',
      line: '204',
      origin: 'Parada Gral. Camacho',
      destination: 'Av. 6 de Marzo',
      fareBs: 2.5,
      serviceHours: '06:00 - 21:00',
      description:
          'Ejemplo con variacion por feria: jueves y domingo no llega al destino final.',
      averageSpeedKmh: 19,
      isOfficial: false,
      stops: const [
        'Parada Gral. Camacho',
        'Plaza Ballivian salida de combis',
        'Av. 6 de Marzo',
      ],
      fareRules: const [
        FareRule(
          label: 'Hasta Plaza Ballivian',
          destination: 'Plaza Ballivian salida de combis',
          fareBs: 2,
        ),
        FareRule(
          label: 'Hasta Av. 6 de Marzo',
          destination: 'Av. 6 de Marzo',
          fareBs: 2.5,
        ),
      ],
      scheduleRules: const [
        RouteScheduleRule(
          name: 'Feria jueves y domingo',
          weekdays: [DateTime.thursday, DateTime.sunday],
          activeDestination: 'Plaza Ballivian salida de combis',
          pathPointLimit: 2,
          fareOverrideBs: 2,
          note:
              'Por feria, esta linea llega solo hasta Plaza Ballivian durante jueves y domingo.',
        ),
      ],
      path: const [
        LatLng(-16.466440, -68.198256),
        LatLng(-16.488142, -68.171724),
        LatLng(-16.505597, -68.163337),
      ],
    ),
  ];
  static final Set<String> _savedRouteIds = {'piloto-casa-u'};
  static final List<RouteReport> _reports = [];

  @override
  Future<List<TransitRoute>> getRoutes() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_routes);
  }

  @override
  Future<void> addRoute(TransitRoute route) async {
    _routes.add(route);
    _savedRouteIds.add(route.id);
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    _routes.removeWhere((route) => route.id == routeId);
    _savedRouteIds.remove(routeId);
    _reports.removeWhere((report) => report.routeId == routeId);
  }

  @override
  Future<List<TransitRoute>> getSavedRoutes() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _routes
        .where((route) => _savedRouteIds.contains(route.id))
        .toList(growable: false);
  }

  @override
  Future<bool> isRouteSaved(String routeId) async {
    return _savedRouteIds.contains(routeId);
  }

  @override
  Future<void> toggleSavedRoute(String routeId) async {
    if (_savedRouteIds.contains(routeId)) {
      _savedRouteIds.remove(routeId);
    } else {
      _savedRouteIds.add(routeId);
    }
  }

  @override
  Future<List<BusPosition>> getBusPositions(String routeId) async {
    final route = _routes.firstWhere((item) => item.id == routeId);
    final now = DateTime.now();

    return [
      BusPosition(
        id: 'bus-101',
        routeId: routeId,
        location: route.path.first,
        updatedAt: now,
      ),
      BusPosition(
        id: 'bus-214',
        routeId: routeId,
        location: route.path[route.path.length ~/ 2],
        updatedAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  @override
  Future<List<RouteReport>> getReports(String routeId) async {
    return _reports
        .where((report) => report.routeId == routeId)
        .toList(growable: false);
  }

  @override
  Future<void> addReport(RouteReport report) async {
    _reports.add(report);
  }
}
