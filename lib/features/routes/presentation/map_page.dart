import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_theme.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/bus_position.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/deviation_detector.dart';
import '../domain/services/eta_service.dart';
import '../domain/services/route_availability_service.dart';
import 'add_route_page.dart';
import 'route_detail_page.dart';
import 'widgets/bus_marker.dart';

class MapPage extends StatefulWidget {
  const MapPage({this.initialRouteId, super.key});

  final String? initialRouteId;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _elAltoCenter = LatLng(-16.5046, -68.1730);

  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _etaService = const EtaService();
  final _deviationDetector = const DeviationDetector();
  final _availabilityService = const RouteAvailabilityService();

  List<TransitRoute> _routes = [];
  List<BusPosition> _buses = [];
  RouteAvailabilityInfo? _activeInfo;
  TransitRoute? _selectedRoute;
  TransportType? _selectedTransportType;
  bool _isLoading = true;

  List<TransitRoute> get _visibleRoutes {
    if (_selectedTransportType == null) return _routes;
    return _routes
        .where((route) => route.transportType == _selectedTransportType)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    final routes = await _repository.getRoutes();
    TransitRoute? selectedRoute;

    if (widget.initialRouteId != null && routes.isNotEmpty) {
      selectedRoute = routes.firstWhere(
        (route) => route.id == widget.initialRouteId,
        orElse: () => routes.first,
      );
    }

    setState(() {
      _routes = routes;
      _selectedRoute = selectedRoute;
      _selectedTransportType = selectedRoute?.transportType;
      _isLoading = false;
    });

    if (selectedRoute != null) {
      await _showRoute(selectedRoute);
    }
  }

  Future<void> _showRoute(TransitRoute route) async {
    final buses = await _repository.getBusPositions(route.id);
    final activeInfo = _availabilityService.evaluate(route, DateTime.now());

    if (!mounted) return;

    setState(() {
      _selectedRoute = route;
      _selectedTransportType = route.transportType;
      _buses = buses;
      _activeInfo = activeInfo;
    });
  }

  void _selectTransportType(TransportType? type) {
    setState(() {
      _selectedTransportType = type;
      if (_selectedRoute != null &&
          type != null &&
          _selectedRoute!.transportType != type) {
        _selectedRoute = null;
        _buses = [];
        _activeInfo = null;
      }
    });
  }

  Future<void> _selectRoute(String? routeId) async {
    if (routeId == null) return;
    final route = _routes.firstWhere((item) => item.id == routeId);
    await _showRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = _selectedRoute;
    final activeInfo = _activeInfo;
    final visibleRoutes = _visibleRoutes;
    final selectedRouteId =
        visibleRoutes.any((route) => route.id == selectedRoute?.id)
        ? selectedRoute?.id
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de transportes'),
        actions: [
          IconButton(
            tooltip: 'Agregar ruta',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddRoutePage()));
              await _loadMapData();
            },
            icon: PhosphorIcon(PhosphorIcons.mapPin()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transportes publicos de El Alto',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('Todos'),
                                selected: _selectedTransportType == null,
                                onSelected: (_) => _selectTransportType(null),
                              ),
                            ),
                            for (final type in TransportType.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: Icon(_iconFor(type), size: 16),
                                  showCheckmark: false,
                                  label: Text(type.label),
                                  selected: _selectedTransportType == type,
                                  onSelected: (_) => _selectTransportType(type),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRouteId,
                        decoration: InputDecoration(
                          labelText: 'Selecciona una ruta',
                          prefixIcon: PhosphorIcon(PhosphorIcons.path()),
                        ),
                        items: visibleRoutes
                            .map(
                              (route) => DropdownMenuItem(
                                value: route.id,
                                child: Text(route.name),
                              ),
                            )
                            .toList(),
                        onChanged: _selectRoute,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    key: ValueKey(selectedRoute?.id ?? 'el-alto'),
                    options: MapOptions(
                      initialCenter: selectedRoute?.path.first ?? _elAltoCenter,
                      initialZoom: selectedRoute == null ? 13 : 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mi_app',
                      ),
                      if (selectedRoute != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: activeInfo?.activePath ?? selectedRoute.path,
                              color: Colors.blue,
                              strokeWidth: 5,
                            ),
                          ],
                        ),
                      if (selectedRoute != null)
                        MarkerLayer(
                          markers: [
                            for (final bus in _buses)
                              Marker(
                                point: bus.location,
                                width: 48,
                                height: 48,
                                alignment: Alignment.topCenter,
                                child: BusMarker(
                                  size: 48,
                                  icon: _iconFor(
                                    selectedRoute.transportType,
                                    PhosphorIconsStyle.fill,
                                  ),
                                  color:
                                      _deviationDetector.isOutsideRoute(
                                        bus.location,
                                        selectedRoute,
                                      )
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                selectedRoute == null
                    ? const _EmptyMapSummary()
                    : _MapSummary(
                        route: selectedRoute,
                        buses: _buses,
                        eta: _etaService.estimateArrival(selectedRoute),
                        activeInfo: activeInfo,
                        onOpenDetail: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RouteDetailPage(route: selectedRoute),
                                ),
                              )
                              .then((_) => _loadMapData());
                        },
                      ),
              ],
            ),
    );
  }

  IconData _iconFor(
    TransportType type, [
    PhosphorIconsStyle style = PhosphorIconsStyle.regular,
  ]) {
    return switch (type) {
      TransportType.minibus => PhosphorIcons.van(style),
      TransportType.trufi => PhosphorIcons.taxi(style),
      TransportType.micro => PhosphorIcons.bus(style),
    };
  }
}

class _EmptyMapSummary extends StatelessWidget {
  const _EmptyMapSummary();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Elige un transporte para ver su recorrido',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class _MapSummary extends StatelessWidget {
  const _MapSummary({
    required this.route,
    required this.buses,
    required this.eta,
    required this.activeInfo,
    required this.onOpenDetail,
  });

  final TransitRoute route;
  final List<BusPosition> buses;
  final Duration eta;
  final RouteAvailabilityInfo? activeInfo;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(route.transportType);

    return Material(
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    route.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  avatar: PhosphorIcon(PhosphorIcons.clock(), color: color, size: 16),
                  label: Text('${eta.inMinutes} min'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${route.transportType.label} ${route.line} - ${route.syndicate}',
            ),
            const SizedBox(height: 6),
            Text(
              'Bs ${(activeInfo?.fareBs ?? route.fareBs).toStringAsFixed(1)} - ${route.serviceHours} - '
              '${buses.length} buses',
            ),
            if (route.recordedStartedAt != null) ...[
              const SizedBox(height: 6),
              Text('Grabada: ${_formatDateTime(route.recordedStartedAt!)}'),
            ],
            if (route.variationReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Causa: ${route.variationReason}'),
            ],
            if (activeInfo != null) ...[
              const SizedBox(height: 6),
              Text(
                activeInfo!.isModified
                    ? 'Hoy: ${activeInfo!.note}'
                    : activeInfo!.note,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                const _LegendItem(color: Colors.blue, label: 'Recorrido'),
                const _LegendItem(color: Colors.green, label: 'Bus activo'),
                TextButton.icon(
                  onPressed: onOpenDetail,
                  icon: PhosphorIcon(PhosphorIcons.info()),
                  label: const Text('Detalle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(TransportType type) {
    return switch (type) {
      TransportType.minibus => AppTheme.minibus,
      TransportType.trufi => AppTheme.trufi,
      TransportType.micro => AppTheme.micro,
    };
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhosphorIcon(PhosphorIcons.circle(PhosphorIconsStyle.fill), color: color, size: 10),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
