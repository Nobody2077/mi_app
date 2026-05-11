import 'package:latlong2/latlong.dart';

import '../models/transit_route.dart';

class RouteAvailabilityService {
  const RouteAvailabilityService();

  RouteAvailabilityInfo evaluate(TransitRoute route, DateTime dateTime) {
    RouteScheduleRule? activeRule;
    for (final rule in route.scheduleRules) {
      if (rule.appliesAt(dateTime)) {
        activeRule = rule;
        break;
      }
    }

    final activeFare =
        activeRule?.fareOverrideBs ?? _fareFor(route, dateTime) ?? route.fareBs;

    final activeDestination =
        activeRule?.activeDestination ?? route.destination;
    final activePath = _activePath(route.path, activeRule?.pathPointLimit);

    return RouteAvailabilityInfo(
      destination: activeDestination,
      fareBs: activeFare,
      note: activeRule?.note ?? 'Ruta disponible segun recorrido registrado.',
      isModified: activeRule != null,
      activePath: activePath,
    );
  }

  List<LatLng> _activePath(List<LatLng> path, int? pointLimit) {
    if (pointLimit == null || pointLimit >= path.length) return path;
    if (pointLimit < 2) return path.take(2).toList();
    return path.take(pointLimit).toList();
  }

  double? _fareFor(TransitRoute route, DateTime dateTime) {
    for (final rule in route.fareRules) {
      if (rule.appliesAt(dateTime)) return rule.fareBs;
    }
    return null;
  }
}

class RouteAvailabilityInfo {
  const RouteAvailabilityInfo({
    required this.destination,
    required this.fareBs,
    required this.note,
    required this.isModified,
    required this.activePath,
  });

  final String destination;
  final double fareBs;
  final String note;
  final bool isModified;
  final List<LatLng> activePath;
}
