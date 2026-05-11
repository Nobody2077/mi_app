import 'package:latlong2/latlong.dart';

class BusPosition {
  const BusPosition({
    required this.id,
    required this.routeId,
    required this.location,
    required this.updatedAt,
  });

  final String id;
  final String routeId;
  final LatLng location;
  final DateTime updatedAt;
}
