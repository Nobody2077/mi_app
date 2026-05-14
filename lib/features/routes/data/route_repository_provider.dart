import '../domain/repositories/route_repository.dart';
import 'local_route_repository.dart';

class RouteRepositoryProvider {
  const RouteRepositoryProvider._();

  static RouteRepository get instance => LocalRouteRepository.instance;
}
