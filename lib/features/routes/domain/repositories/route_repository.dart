import '../models/bus_position.dart';
import '../models/route_report.dart';
import '../models/transit_route.dart';

abstract class RouteRepository {
  Future<List<TransitRoute>> getRoutes();

  Future<void> addRoute(TransitRoute route);

  Future<void> deleteRoute(String routeId);

  Future<List<TransitRoute>> getSavedRoutes();

  Future<bool> isRouteSaved(String routeId);

  Future<void> toggleSavedRoute(String routeId);

  Future<List<BusPosition>> getBusPositions(String routeId);

  Future<List<RouteReport>> getReports(String routeId);

  Future<void> addReport(RouteReport report);
}
