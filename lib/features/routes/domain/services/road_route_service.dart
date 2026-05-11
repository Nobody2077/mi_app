import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

class RoadRouteService {
  const RoadRouteService();

  Future<List<LatLng>> snapToRoads(List<LatLng> controlPoints) async {
    if (controlPoints.length < 2) return controlPoints;

    final coordinates = controlPoints
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$coordinates',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'ruta-facil-el-alto');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != HttpStatus.ok) return controlPoints;

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return controlPoints;

      final geometry = routes.first['geometry'] as Map<String, dynamic>;
      final points = geometry['coordinates'] as List<dynamic>;

      return points.map((coordinate) {
        final pair = coordinate as List<dynamic>;
        final longitude = (pair[0] as num).toDouble();
        final latitude = (pair[1] as num).toDouble();
        return LatLng(latitude, longitude);
      }).toList();
    } on Object {
      return controlPoints;
    } finally {
      client.close(force: true);
    }
  }
}
