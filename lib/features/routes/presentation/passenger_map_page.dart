import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../app/app_theme.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/bus_position.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/deviation_detector.dart';
import '../domain/services/eta_service.dart';
import '../domain/services/nearby_bus_service.dart';
import '../domain/services/route_availability_service.dart';
import 'route_detail_page.dart';
import 'widgets/bus_marker.dart';

enum _LocationStatus { loading, granted, denied, serviceDisabled }

class PassengerMapPage extends StatefulWidget {
  const PassengerMapPage({this.initialRouteId, super.key});

  final String? initialRouteId;

  @override
  State<PassengerMapPage> createState() => _PassengerMapPageState();
}

class _PassengerMapPageState extends State<PassengerMapPage> {
  static const _elAltoCenter = LatLng(-16.5046, -68.1730);

  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _nearbyBusService = const NearbyBusService();
  final _etaService = const EtaService();
  final _availabilityService = const RouteAvailabilityService();
  final _deviationDetector = const DeviationDetector();
  final _mapController = MapController();

  LatLng? _userLocation;
  _LocationStatus _locationStatus = _LocationStatus.loading;

  List<TransitRoute> _routes = [];
  Map<String, List<BusPosition>> _busesByRoute = {};
  TransportType? _selectedTransportType;
  List<NearbyBus> _nearbyBuses = [];
  bool _isLoadingRoutes = true;

  TransitRoute? _selectedRoute;
  RouteAvailabilityInfo? _activeInfo;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _resolveUserLocation();
  }

  Future<void> _loadRoutes() async {
    final routes = await _repository.getRoutes();
    final entries = await Future.wait(
      routes.map((route) async {
        final buses = await _repository.getBusPositions(route.id);
        return MapEntry(route.id, buses);
      }),
    );

    if (!mounted) return;
    setState(() {
      _routes = routes;
      _busesByRoute = Map.fromEntries(entries);
      _isLoadingRoutes = false;
    });
    _updateNearbyBuses();

    final initialRouteId = widget.initialRouteId;
    if (initialRouteId != null) {
      final route = routes.where((item) => item.id == initialRouteId);
      if (route.isNotEmpty) _selectRoute(route.first);
    }
  }

  void _updateNearbyBuses() {
    final userLocation = _userLocation;
    setState(() {
      _nearbyBuses = userLocation == null
          ? []
          : _nearbyBusService.findNearby(
              userLocation: userLocation,
              routes: _routes,
              busesByRoute: _busesByRoute,
              type: _selectedTransportType,
            );
    });
  }

  void _selectTransportType(TransportType? type) {
    setState(() => _selectedTransportType = type);
    _updateNearbyBuses();
  }

  void _selectRoute(TransitRoute route) {
    setState(() {
      _selectedRoute = route;
      _activeInfo = _availabilityService.evaluate(route, DateTime.now());
    });
    if (route.path.isNotEmpty) {
      _mapController.move(route.path.first, 14);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedRoute = null;
      _activeInfo = null;
    });
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

  Color _colorFor(TransportType type) {
    return switch (type) {
      TransportType.minibus => AppTheme.minibus,
      TransportType.trufi => AppTheme.trufi,
      TransportType.micro => AppTheme.micro,
    };
  }

  Future<void> _resolveUserLocation() async {
    setState(() => _locationStatus = _LocationStatus.loading);

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.serviceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.denied);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = location;
        _locationStatus = _LocationStatus.granted;
      });
      _updateNearbyBuses();
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.denied);
    }
  }

  Future<void> _centerOnUserLocation() async {
    await _resolveUserLocation();
    final location = _userLocation;
    if (!mounted || location == null) return;
    _mapController.move(location, 16);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoute = _selectedRoute;
    final activeInfo = _activeInfo;
    final selectedPath = selectedRoute == null
        ? const <LatLng>[]
        : (activeInfo?.activePath ?? selectedRoute.path);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedRoute?.name ?? 'Mapa'),
        leading: selectedRoute != null
            ? IconButton(
                icon: PhosphorIcon(PhosphorIcons.arrowLeft()),
                onPressed: _clearSelection,
              )
            : null,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _elAltoCenter,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mi_app',
              ),
              if (selectedRoute != null && selectedPath.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    // Borde blanco bajo la linea de color para que la ruta
                    // resalte sobre las calles del mapa.
                    Polyline(
                      points: selectedPath,
                      color: Colors.white,
                      strokeWidth: 9,
                    ),
                    Polyline(
                      points: selectedPath,
                      color: _colorFor(selectedRoute.transportType),
                      strokeWidth: 5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedPath.first,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorFor(selectedRoute.transportType),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Marker(
                      point: selectedPath.last,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: BusMarker(
                        size: 40,
                        icon: PhosphorIcons.flagCheckered(
                          PhosphorIconsStyle.fill,
                        ),
                        color: _colorFor(selectedRoute.transportType),
                      ),
                    ),
                  ],
                ),
              ],
              if (selectedRoute != null)
                MarkerLayer(
                  markers: [
                    for (final bus in _busesByRoute[selectedRoute.id] ?? const [])
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
              if (selectedRoute == null && _nearbyBuses.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final nearby in _nearbyBuses)
                      Marker(
                        point: nearby.bus.location,
                        width: 42,
                        height: 42,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _selectRoute(nearby.route),
                          child: BusMarker(
                            icon: _iconFor(
                              nearby.route.transportType,
                              PhosphorIconsStyle.fill,
                            ),
                            color: _colorFor(nearby.route.transportType),
                          ),
                        ),
                      ),
                  ],
                ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedRoute == null) ...[
                  if (_isLoadingRoutes)
                    const _InfoCard(
                      icon: null,
                      message: 'Cargando rutas...',
                      showSpinner: true,
                    )
                  else
                    _TransportTypeChips(
                      selected: _selectedTransportType,
                      iconFor: _iconFor,
                      onSelected: _selectTransportType,
                    ),
                  if (!_isLoadingRoutes &&
                      _userLocation != null &&
                      _nearbyBuses.isEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoCard(
                      icon: PhosphorIcons.info(),
                      message: _selectedTransportType == null
                          ? 'No se encontraron buses cercanos por ahora.'
                          : 'No hay ${_selectedTransportType!.label} cerca. '
                                'Prueba con otro tipo o "Todos".',
                    ),
                  ],
                ],
                if (_locationStatus != _LocationStatus.granted) ...[
                  const SizedBox(height: 8),
                  _LocationBanner(
                    status: _locationStatus,
                    onRetry: _resolveUserLocation,
                  ),
                ],
              ],
            ),
          ),
          if (selectedRoute != null && activeInfo != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PassengerRouteSummary(
                route: selectedRoute,
                eta: _etaService.estimateArrival(selectedRoute),
                activeInfo: activeInfo,
                color: _colorFor(selectedRoute.transportType),
                onOpenDetail: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RouteDetailPage(route: selectedRoute),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: selectedRoute == null
          ? FloatingActionButton(
              onPressed: _centerOnUserLocation,
              tooltip: 'Centrar en mi ubicacion',
              child: PhosphorIcon(PhosphorIcons.gpsFix()),
            )
          : null,
    );
  }
}

class _TransportTypeChips extends StatelessWidget {
  const _TransportTypeChips({
    required this.selected,
    required this.iconFor,
    required this.onSelected,
  });

  final TransportType? selected;
  final IconData Function(TransportType type) iconFor;
  final ValueChanged<TransportType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                ),
              ),
              for (final type in TransportType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(iconFor(type), size: 16),
                    showCheckmark: false,
                    label: Text(type.label),
                    selected: selected == type,
                    onSelected: (_) => onSelected(type),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassengerRouteSummary extends StatelessWidget {
  const _PassengerRouteSummary({
    required this.route,
    required this.eta,
    required this.activeInfo,
    required this.color,
    required this.onOpenDetail,
  });

  final TransitRoute route;
  final Duration eta;
  final RouteAvailabilityInfo activeInfo;
  final Color color;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                  avatar: PhosphorIcon(
                    PhosphorIcons.clock(),
                    color: color,
                    size: 16,
                  ),
                  label: Text('${eta.inMinutes} min'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(route.transportType.label)),
                Chip(label: Text('Bs ${activeInfo.fareBs.toStringAsFixed(1)}')),
                Chip(label: Text(route.serviceHours)),
              ],
            ),
            if (activeInfo.isModified) ...[
              const SizedBox(height: 8),
              Text(
                activeInfo.note,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onOpenDetail,
              icon: PhosphorIcon(PhosphorIcons.info()),
              label: const Text('Ver detalle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.message,
    this.showSpinner = false,
  });

  final IconData? icon;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              PhosphorIcon(icon!),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.status, required this.onRetry});

  final _LocationStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      _LocationStatus.serviceDisabled =>
        'Activa el GPS para ver tu ubicacion y los buses cercanos.',
      _LocationStatus.denied =>
        'Activa el permiso de ubicacion para ver los buses cercanos.',
      _LocationStatus.loading || _LocationStatus.granted => null,
    };

    if (message == null) return const SizedBox.shrink();

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PhosphorIcon(PhosphorIcons.warning()),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
