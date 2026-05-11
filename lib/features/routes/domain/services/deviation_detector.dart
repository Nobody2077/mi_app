import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/geo_utils.dart';
import '../models/transit_route.dart';

class DeviationDetector {
  const DeviationDetector();

  bool isOutsideRoute(
    LatLng currentLocation,
    TransitRoute route, {
    double thresholdMeters = AppConstants.deviationThresholdMeters,
  }) {
    final distance = GeoUtils.distanceToPolylineInMeters(
      currentLocation,
      route.path,
    );

    return distance > thresholdMeters;
  }
}
