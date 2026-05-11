import '../../../../core/utils/geo_utils.dart';
import '../models/transit_route.dart';

class EtaService {
  const EtaService();

  Duration estimateArrival(TransitRoute route) {
    final distanceKm = GeoUtils.polylineDistanceInMeters(route.path) / 1000;
    final hours = distanceKm / route.averageSpeedKmh;

    return Duration(minutes: (hours * 60).ceil());
  }
}
