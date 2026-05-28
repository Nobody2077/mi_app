import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models/bus_position.dart';
import '../domain/models/route_report.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import 'route_json_codec.dart';

class LocalRouteRepository implements RouteRepository {
  LocalRouteRepository._();

  static final LocalRouteRepository instance = LocalRouteRepository._();
  static const _demoRouteIds = [
    'ceja-villa-adela',
    'ceja-senkata',
    'ceja-rio-seco',
    'piloto-casa-u',
    'linea-204-ballivian-ceja',
  ];
  static const _bundledRouteSeeds = [
    _BundledRouteSeed(
      routeId: 'manual-1779730822843',
      metadataKey: 'seeded_route_manual_1779730822843',
      assetPath: 'assets/routes/ruta_facil_no_tiene_manual-1779730822843.json',
      saveRoute: true,
    ),
    _BundledRouteSeed(
      routeId: 'manual-1779759085763',
      metadataKey: 'seeded_route_manual_1779759085763',
      assetPath: 'assets/routes/ruta_facil_204_manual-1779759085763.json',
      saveRoute: true,
    ),
  ];

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final database = await openDatabase(
      p.join(databasesPath, 'ruta_facil_el_alto.db'),
      version: 2,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    _database = database;
    return database;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        transport_type TEXT NOT NULL,
        syndicate TEXT NOT NULL,
        line TEXT NOT NULL,
        origin TEXT NOT NULL,
        destination TEXT NOT NULL,
        fare_bs REAL NOT NULL,
        service_hours TEXT NOT NULL,
        description TEXT NOT NULL,
        average_speed_kmh REAL NOT NULL,
        is_official INTEGER NOT NULL DEFAULT 0,
        variation_reason TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        recorded_started_at TEXT,
        recorded_ended_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE route_stops (
        route_id TEXT NOT NULL,
        stop_order INTEGER NOT NULL,
        name TEXT NOT NULL,
        PRIMARY KEY (route_id, stop_order)
      )
    ''');
    await db.execute('''
      CREATE TABLE route_points (
        route_id TEXT NOT NULL,
        point_order INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        PRIMARY KEY (route_id, point_order)
      )
    ''');
    await db.execute('''
      CREATE TABLE fare_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        label TEXT NOT NULL,
        destination TEXT NOT NULL,
        fare_bs REAL NOT NULL,
        weekdays TEXT NOT NULL,
        start_hour INTEGER NOT NULL,
        end_hour INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE schedule_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id TEXT NOT NULL,
        name TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        start_hour INTEGER NOT NULL,
        end_hour INTEGER NOT NULL,
        note TEXT NOT NULL,
        active_destination TEXT,
        path_point_limit INTEGER,
        fare_override_bs REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE saved_routes (
        route_id TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE route_reports (
        id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        type TEXT NOT NULL,
        comment TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        for (final routeId in _demoRouteIds) {
          await _deleteRoute(txn, routeId);
        }
        await txn.delete(
          'metadata',
          where: 'key = ?',
          whereArgs: ['seeded_v1'],
        );
      });
    }
  }

  @override
  Future<List<TransitRoute>> getRoutes() async {
    final db = await _db;
    await _seedBundledRoutesIfNeeded(db);
    final routeRows = await db.query('routes', orderBy: 'created_at DESC');
    final routes = <TransitRoute>[];
    for (final row in routeRows) {
      routes.add(await _routeFromRow(db, row));
    }
    return routes;
  }

  @override
  Future<void> addRoute(TransitRoute route) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteRouteChildren(txn, route.id);
      await _insertRoute(txn, route, saveRoute: true);
    });
  }

  @override
  Future<void> deleteRoute(String routeId) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteRoute(txn, routeId);
    });
  }

  @override
  Future<List<TransitRoute>> getSavedRoutes() async {
    final db = await _db;
    await _seedBundledRoutesIfNeeded(db);
    final rows = await db.rawQuery('''
      SELECT routes.*
      FROM routes
      INNER JOIN saved_routes ON saved_routes.route_id = routes.id
      ORDER BY routes.created_at DESC
    ''');
    final routes = <TransitRoute>[];
    for (final row in rows) {
      routes.add(await _routeFromRow(db, row));
    }
    return routes;
  }

  Future<void> _seedBundledRoutesIfNeeded(Database db) async {
    for (final seed in _bundledRouteSeeds) {
      final seeded = await db.query(
        'metadata',
        where: 'key = ?',
        whereArgs: [seed.metadataKey],
        limit: 1,
      );
      if (seeded.isNotEmpty) continue;

      final existing = await db.query(
        'routes',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [seed.routeId],
        limit: 1,
      );

      await db.transaction((txn) async {
        if (existing.isEmpty) {
          final route = await _loadBundledRoute(seed.assetPath);
          await _insertRoute(txn, route, saveRoute: seed.saveRoute);
        } else if (seed.saveRoute) {
          await txn.insert('saved_routes', {
            'route_id': seed.routeId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        await txn.insert('metadata', {
          'key': seed.metadataKey,
          'value': '1',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    }
  }

  Future<TransitRoute> _loadBundledRoute(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    final json = jsonDecode(content);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Route JSON root must be an object.');
    }
    return const RouteJsonCodec().decodeRoute(json);
  }

  @override
  Future<bool> isRouteSaved(String routeId) async {
    final db = await _db;
    final rows = await db.query(
      'saved_routes',
      where: 'route_id = ?',
      whereArgs: [routeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> toggleSavedRoute(String routeId) async {
    final db = await _db;
    if (await isRouteSaved(routeId)) {
      await db.delete(
        'saved_routes',
        where: 'route_id = ?',
        whereArgs: [routeId],
      );
    } else {
      await db.insert('saved_routes', {'route_id': routeId});
    }
  }

  @override
  Future<List<BusPosition>> getBusPositions(String routeId) async {
    final route = (await getRoutes()).firstWhere((item) => item.id == routeId);
    final now = DateTime.now();
    if (route.path.isEmpty) return [];

    return [
      BusPosition(
        id: 'bus-$routeId-1',
        routeId: routeId,
        location: route.path.first,
        updatedAt: now,
      ),
      if (route.path.length > 2)
        BusPosition(
          id: 'bus-$routeId-2',
          routeId: routeId,
          location: route.path[route.path.length ~/ 2],
          updatedAt: now.subtract(const Duration(minutes: 2)),
        ),
    ];
  }

  @override
  Future<List<RouteReport>> getReports(String routeId) async {
    final db = await _db;
    final rows = await db.query(
      'route_reports',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_reportFromRow).toList(growable: false);
  }

  @override
  Future<void> addReport(RouteReport report) async {
    final db = await _db;
    await db.insert('route_reports', {
      'id': report.id,
      'route_id': report.routeId,
      'type': report.type.name,
      'comment': report.comment,
      'created_at': report.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _insertRoute(
    DatabaseExecutor db,
    TransitRoute route, {
    required bool saveRoute,
  }) async {
    await db.insert('routes', {
      'id': route.id,
      'name': route.name,
      'transport_type': route.transportType.name,
      'syndicate': route.syndicate,
      'line': route.line,
      'origin': route.origin,
      'destination': route.destination,
      'fare_bs': route.fareBs,
      'service_hours': route.serviceHours,
      'description': route.description,
      'average_speed_kmh': route.averageSpeedKmh,
      'is_official': route.isOfficial ? 1 : 0,
      'variation_reason': route.variationReason,
      'created_at': (route.createdAt ?? DateTime.now()).toIso8601String(),
      'recorded_started_at': route.recordedStartedAt?.toIso8601String(),
      'recorded_ended_at': route.recordedEndedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    for (var index = 0; index < route.stops.length; index++) {
      await db.insert('route_stops', {
        'route_id': route.id,
        'stop_order': index,
        'name': route.stops[index],
      });
    }

    for (var index = 0; index < route.path.length; index++) {
      final point = route.path[index];
      await db.insert('route_points', {
        'route_id': route.id,
        'point_order': index,
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
    }

    for (final rule in route.fareRules) {
      await db.insert('fare_rules', {
        'route_id': route.id,
        'label': rule.label,
        'destination': rule.destination,
        'fare_bs': rule.fareBs,
        'weekdays': _encodeWeekdays(rule.weekdays),
        'start_hour': rule.startHour,
        'end_hour': rule.endHour,
      });
    }

    for (final rule in route.scheduleRules) {
      await db.insert('schedule_rules', {
        'route_id': route.id,
        'name': rule.name,
        'weekdays': _encodeWeekdays(rule.weekdays),
        'start_hour': rule.startHour,
        'end_hour': rule.endHour,
        'note': rule.note,
        'active_destination': rule.activeDestination,
        'path_point_limit': rule.pathPointLimit,
        'fare_override_bs': rule.fareOverrideBs,
      });
    }

    if (saveRoute) {
      await db.insert('saved_routes', {
        'route_id': route.id,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _deleteRouteChildren(DatabaseExecutor db, String routeId) async {
    for (final table in [
      'route_stops',
      'route_points',
      'fare_rules',
      'schedule_rules',
      'saved_routes',
      'route_reports',
    ]) {
      await db.delete(table, where: 'route_id = ?', whereArgs: [routeId]);
    }
  }

  Future<void> _deleteRoute(DatabaseExecutor db, String routeId) async {
    await _deleteRouteChildren(db, routeId);
    await db.delete('routes', where: 'id = ?', whereArgs: [routeId]);
  }

  Future<TransitRoute> _routeFromRow(
    Database db,
    Map<String, Object?> row,
  ) async {
    final routeId = row['id']! as String;
    final stops = await db.query(
      'route_stops',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'stop_order ASC',
    );
    final points = await db.query(
      'route_points',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'point_order ASC',
    );
    final fareRules = await db.query(
      'fare_rules',
      where: 'route_id = ?',
      whereArgs: [routeId],
    );
    final scheduleRules = await db.query(
      'schedule_rules',
      where: 'route_id = ?',
      whereArgs: [routeId],
    );

    return TransitRoute(
      id: routeId,
      name: row['name']! as String,
      transportType: _transportTypeFromName(row['transport_type']! as String),
      syndicate: row['syndicate']! as String,
      line: row['line']! as String,
      origin: row['origin']! as String,
      destination: row['destination']! as String,
      fareBs: (row['fare_bs']! as num).toDouble(),
      serviceHours: row['service_hours']! as String,
      description: row['description']! as String,
      averageSpeedKmh: (row['average_speed_kmh']! as num).toDouble(),
      stops: stops
          .map((item) => item['name']! as String)
          .toList(growable: false),
      path: points
          .map(
            (item) => LatLng(
              (item['latitude']! as num).toDouble(),
              (item['longitude']! as num).toDouble(),
            ),
          )
          .toList(growable: false),
      createdAt: _parseDate(row['created_at']),
      recordedStartedAt: _parseDate(row['recorded_started_at']),
      recordedEndedAt: _parseDate(row['recorded_ended_at']),
      variationReason: row['variation_reason']! as String,
      isOfficial: (row['is_official']! as int) == 1,
      fareRules: fareRules.map(_fareRuleFromRow).toList(growable: false),
      scheduleRules: scheduleRules
          .map(_scheduleRuleFromRow)
          .toList(growable: false),
    );
  }

  FareRule _fareRuleFromRow(Map<String, Object?> row) {
    return FareRule(
      label: row['label']! as String,
      destination: row['destination']! as String,
      fareBs: (row['fare_bs']! as num).toDouble(),
      weekdays: _decodeWeekdays(row['weekdays']! as String),
      startHour: row['start_hour']! as int,
      endHour: row['end_hour']! as int,
    );
  }

  RouteScheduleRule _scheduleRuleFromRow(Map<String, Object?> row) {
    return RouteScheduleRule(
      name: row['name']! as String,
      weekdays: _decodeWeekdays(row['weekdays']! as String),
      startHour: row['start_hour']! as int,
      endHour: row['end_hour']! as int,
      note: row['note']! as String,
      activeDestination: row['active_destination'] as String?,
      pathPointLimit: row['path_point_limit'] as int?,
      fareOverrideBs: (row['fare_override_bs'] as num?)?.toDouble(),
    );
  }

  RouteReport _reportFromRow(Map<String, Object?> row) {
    return RouteReport(
      id: row['id']! as String,
      routeId: row['route_id']! as String,
      type: ReportType.values.byName(row['type']! as String),
      comment: row['comment']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
    );
  }

  TransportType _transportTypeFromName(String name) {
    return TransportType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => TransportType.minibus,
    );
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  String _encodeWeekdays(List<int> weekdays) {
    return weekdays.join(',');
  }

  List<int> _decodeWeekdays(String value) {
    if (value.trim().isEmpty) return [];
    return value
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList(growable: false);
  }
}

class _BundledRouteSeed {
  const _BundledRouteSeed({
    required this.routeId,
    required this.metadataKey,
    required this.assetPath,
    required this.saveRoute,
  });

  final String routeId;
  final String metadataKey;
  final String assetPath;
  final bool saveRoute;
}
