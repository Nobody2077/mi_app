import 'package:latlong2/latlong.dart';

class GeoUtils {
  const GeoUtils._();

  static final Distance _distance = const Distance();

  static double distanceInMeters(LatLng origin, LatLng destination) {
    return _distance.as(LengthUnit.Meter, origin, destination);
  }

  static double polylineDistanceInMeters(List<LatLng> points) {
    if (points.length < 2) return 0;

    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += distanceInMeters(points[i], points[i + 1]);
    }
    return total;
  }

  static double distanceToPolylineInMeters(LatLng point, List<LatLng> route) {
    if (route.isEmpty) return double.infinity;

    return route
        .map((routePoint) => distanceInMeters(point, routePoint))
        .reduce((value, element) => value < element ? value : element);
  }
}
