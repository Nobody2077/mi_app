import 'package:latlong2/latlong.dart';

import '../domain/models/transit_route.dart';

class RouteJsonCodec {
  const RouteJsonCodec();

  TransitRoute decodeRoute(Map<String, Object?> json) {
    final route = _asMap(json['route'], 'route');
    final stops = _orderedMaps(json['stops'], 'stops')
        .map((item) => _asString(item['name'], 'stops.name'))
        .toList(growable: false);
    final points = _orderedMaps(json['points'], 'points')
        .map(
          (item) => LatLng(
            _asDouble(item['latitude'], 'points.latitude'),
            _asDouble(item['longitude'], 'points.longitude'),
          ),
        )
        .toList(growable: false);

    return TransitRoute(
      id: _asString(route['id'], 'route.id'),
      name: _asString(route['name'], 'route.name'),
      transportType: _transportTypeFromName(
        _asString(route['transport_type'], 'route.transport_type'),
      ),
      syndicate: _asString(route['syndicate'], 'route.syndicate'),
      line: _asString(route['line'], 'route.line'),
      origin: _asString(route['origin'], 'route.origin'),
      destination: _asString(route['destination'], 'route.destination'),
      fareBs: _asDouble(route['fare_bs'], 'route.fare_bs'),
      serviceHours: _asString(route['service_hours'], 'route.service_hours'),
      description: _asString(route['description'], 'route.description'),
      averageSpeedKmh: _asDouble(
        route['average_speed_kmh'],
        'route.average_speed_kmh',
      ),
      stops: stops,
      path: points,
      createdAt: _parseDate(route['created_at']),
      recordedStartedAt: _parseDate(route['recorded_started_at']),
      recordedEndedAt: _parseDate(route['recorded_ended_at']),
      variationReason: _optionalString(route['variation_reason']) ?? '',
      isOfficial: route['is_official'] == true,
      fareRules: _orderedMaps(
        json['fare_rules'],
        'fare_rules',
      ).map(_fareRuleFromJson).toList(growable: false),
      scheduleRules: _orderedMaps(
        json['schedule_rules'],
        'schedule_rules',
      ).map(_scheduleRuleFromJson).toList(growable: false),
    );
  }

  FareRule _fareRuleFromJson(Map<String, Object?> json) {
    return FareRule(
      label: _asString(json['label'], 'fare_rules.label'),
      destination: _asString(json['destination'], 'fare_rules.destination'),
      fareBs: _asDouble(json['fare_bs'], 'fare_rules.fare_bs'),
      weekdays: _intList(json['weekdays']),
      startHour: _asInt(json['start_hour'], 'fare_rules.start_hour'),
      endHour: _asInt(json['end_hour'], 'fare_rules.end_hour'),
    );
  }

  RouteScheduleRule _scheduleRuleFromJson(Map<String, Object?> json) {
    return RouteScheduleRule(
      name: _asString(json['name'], 'schedule_rules.name'),
      weekdays: _intList(json['weekdays']),
      startHour: _asInt(json['start_hour'], 'schedule_rules.start_hour'),
      endHour: _asInt(json['end_hour'], 'schedule_rules.end_hour'),
      note: _asString(json['note'], 'schedule_rules.note'),
      activeDestination: _optionalString(json['active_destination']),
      pathPointLimit: _optionalInt(json['path_point_limit']),
      fareOverrideBs: _optionalDouble(json['fare_override_bs']),
    );
  }

  TransportType _transportTypeFromName(String name) {
    return TransportType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => TransportType.minibus,
    );
  }

  List<Map<String, Object?>> _orderedMaps(Object? value, String field) {
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('Expected list at $field.');
    }

    final items = value.map((item) => _asMap(item, field)).toList();
    items.sort((a, b) {
      final left = _optionalInt(a['order']);
      final right = _optionalInt(b['order']);
      if (left == null || right == null) return 0;
      return left.compareTo(right);
    });
    return items;
  }

  Map<String, Object?> _asMap(Object? value, String field) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw FormatException('Expected object at $field.');
  }

  String _asString(Object? value, String field) {
    final text = _optionalString(value);
    if (text == null) {
      throw FormatException('Expected text at $field.');
    }
    return text;
  }

  String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  double _asDouble(Object? value, String field) {
    final number = _optionalDouble(value);
    if (number == null) {
      throw FormatException('Expected number at $field.');
    }
    return number;
  }

  double? _optionalDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int _asInt(Object? value, String field) {
    final number = _optionalInt(value);
    if (number == null) {
      throw FormatException('Expected integer at $field.');
    }
    return number;
  }

  int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<int> _intList(Object? value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    return value.map(_optionalInt).whereType<int>().toList(growable: false);
  }

  DateTime? _parseDate(Object? value) {
    final text = _optionalString(value);
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
