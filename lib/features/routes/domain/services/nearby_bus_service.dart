import 'package:latlong2/latlong.dart';

import '../../../../core/utils/geo_utils.dart';
import '../models/bus_position.dart';
import '../models/transit_route.dart';

class NearbyBus {
  const NearbyBus({
    required this.route,
    required this.bus,
    required this.distanceMeters,
  });

  final TransitRoute route;
  final BusPosition bus;
  final double distanceMeters;
}

class NearbyBusService {
  const NearbyBusService();

  List<NearbyBus> findNearby({
    required LatLng userLocation,
    required List<TransitRoute> routes,
    required Map<String, List<BusPosition>> busesByRoute,
    TransportType? type,
    int limit = 10,
  }) {
    final candidates = <NearbyBus>[];

    for (final route in routes) {
      if (type != null && route.transportType != type) continue;

      for (final bus in busesByRoute[route.id] ?? const []) {
        candidates.add(
          NearbyBus(
            route: route,
            bus: bus,
            distanceMeters: GeoUtils.distanceInMeters(
              userLocation,
              bus.location,
            ),
          ),
        );
      }
    }

    candidates.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return candidates.length > limit
        ? candidates.sublist(0, limit)
        : candidates;
  }
}
