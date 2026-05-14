import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models/route_report.dart';
import '../domain/models/transit_route.dart';

class RouteExportService {
  const RouteExportService();

  Future<void> shareRoute({
    required TransitRoute route,
    required List<RouteReport> reports,
    required Rect sharePositionOrigin,
  }) async {
    final file = await _writeRouteFile(route: route, reports: reports);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Exportar ruta ${route.line}',
        subject: 'Ruta Facil El Alto - ${route.name}',
        text: 'Ruta exportada desde Ruta Facil El Alto: ${route.name}',
        files: [XFile(file.path, name: p.basename(file.path))],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<File> _writeRouteFile({
    required TransitRoute route,
    required List<RouteReport> reports,
  }) async {
    final directory = await getTemporaryDirectory();
    final fileName = _fileNameFor(route);
    final file = File(p.join(directory.path, fileName));
    final encoder = const JsonEncoder.withIndent('  ');
    return file.writeAsString(
      encoder.convert(_routeToJson(route, reports)),
      encoding: utf8,
    );
  }

  Map<String, Object?> _routeToJson(
    TransitRoute route,
    List<RouteReport> reports,
  ) {
    return {
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'source': 'ruta_facil_el_alto',
      'route': {
        'id': route.id,
        'name': route.name,
        'transport_type': route.transportType.name,
        'transport_label': route.transportType.label,
        'syndicate': route.syndicate,
        'line': route.line,
        'origin': route.origin,
        'destination': route.destination,
        'fare_bs': route.fareBs,
        'service_hours': route.serviceHours,
        'description': route.description,
        'average_speed_kmh': route.averageSpeedKmh,
        'is_official': route.isOfficial,
        'variation_reason': route.variationReason,
        'created_at': route.createdAt?.toIso8601String(),
        'recorded_started_at': route.recordedStartedAt?.toIso8601String(),
        'recorded_ended_at': route.recordedEndedAt?.toIso8601String(),
      },
      'stops': [
        for (var index = 0; index < route.stops.length; index++)
          {'order': index, 'name': route.stops[index]},
      ],
      'points': [
        for (var index = 0; index < route.path.length; index++)
          {
            'order': index,
            'latitude': route.path[index].latitude,
            'longitude': route.path[index].longitude,
          },
      ],
      'fare_rules': [
        for (final rule in route.fareRules)
          {
            'label': rule.label,
            'destination': rule.destination,
            'fare_bs': rule.fareBs,
            'weekdays': rule.weekdays,
            'start_hour': rule.startHour,
            'end_hour': rule.endHour,
          },
      ],
      'schedule_rules': [
        for (final rule in route.scheduleRules)
          {
            'name': rule.name,
            'weekdays': rule.weekdays,
            'start_hour': rule.startHour,
            'end_hour': rule.endHour,
            'note': rule.note,
            'active_destination': rule.activeDestination,
            'path_point_limit': rule.pathPointLimit,
            'fare_override_bs': rule.fareOverrideBs,
          },
      ],
      'reports': [
        for (final report in reports)
          {
            'id': report.id,
            'route_id': report.routeId,
            'type': report.type.name,
            'type_label': report.type.label,
            'comment': report.comment,
            'created_at': report.createdAt.toIso8601String(),
          },
      ],
    };
  }

  String _fileNameFor(TransitRoute route) {
    final line = _safeFilePart(route.line.isEmpty ? 'ruta' : route.line);
    final id = _safeFilePart(route.id);
    return 'ruta_facil_${line}_$id.json';
  }

  String _safeFilePart(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    return normalized.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
  }
}
