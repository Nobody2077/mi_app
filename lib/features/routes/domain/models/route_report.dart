class RouteReport {
  const RouteReport({
    required this.id,
    required this.routeId,
    required this.type,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String routeId;
  final ReportType type;
  final String comment;
  final DateTime createdAt;
}

enum ReportType {
  routeChanged('Ruta cambiada'),
  traffic('Trancadera'),
  fullVehicle('Movilidad llena'),
  stopChanged('Parada cambiada');

  const ReportType(this.label);

  final String label;
}
