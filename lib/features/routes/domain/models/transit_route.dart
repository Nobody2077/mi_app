import 'package:latlong2/latlong.dart';

enum TransportType {
  minibus('Minibus'),
  trufi('Trufi'),
  micro('Micro');

  const TransportType(this.label);

  final String label;
}

class TransitRoute {
  const TransitRoute({
    required this.id,
    required this.name,
    required this.transportType,
    required this.syndicate,
    required this.line,
    required this.origin,
    required this.destination,
    required this.fareBs,
    required this.serviceHours,
    required this.description,
    required this.averageSpeedKmh,
    required this.stops,
    required this.path,
    this.isOfficial = false,
    this.scheduleRules = const [],
    this.fareRules = const [],
  });

  final String id;
  final String name;
  final TransportType transportType;
  final String syndicate;
  final String line;
  final String origin;
  final String destination;
  final double fareBs;
  final String serviceHours;
  final String description;
  final double averageSpeedKmh;
  final List<String> stops;
  final bool isOfficial;
  final List<RouteScheduleRule> scheduleRules;
  final List<FareRule> fareRules;

  /// Manual control points. With few points this is only a sketch; OSRM can
  /// snap these controls to streets when the app has internet.
  final List<LatLng> path;

  String get searchText {
    return [
      name,
      transportType.label,
      syndicate,
      line,
      origin,
      destination,
      ...stops,
    ].join(' ').toLowerCase();
  }
}

class RouteScheduleRule {
  const RouteScheduleRule({
    required this.name,
    required this.weekdays,
    required this.note,
    this.startHour = 0,
    this.endHour = 23,
    this.activeDestination,
    this.pathPointLimit,
    this.fareOverrideBs,
  });

  final String name;
  final List<int> weekdays;
  final int startHour;
  final int endHour;
  final String note;
  final String? activeDestination;
  final int? pathPointLimit;
  final double? fareOverrideBs;

  bool appliesAt(DateTime dateTime) {
    return weekdays.contains(dateTime.weekday) &&
        dateTime.hour >= startHour &&
        dateTime.hour <= endHour;
  }
}

class FareRule {
  const FareRule({
    required this.label,
    required this.destination,
    required this.fareBs,
    this.weekdays = const [],
    this.startHour = 0,
    this.endHour = 23,
  });

  final String label;
  final String destination;
  final double fareBs;
  final List<int> weekdays;
  final int startHour;
  final int endHour;

  bool appliesAt(DateTime dateTime) {
    final matchesDay = weekdays.isEmpty || weekdays.contains(dateTime.weekday);
    return matchesDay && dateTime.hour >= startHour && dateTime.hour <= endHour;
  }
}
