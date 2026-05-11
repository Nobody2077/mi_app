import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo_utils.dart';
import '../data/mock_route_repository.dart';
import '../domain/models/transit_route.dart';

class AddRoutePage extends StatefulWidget {
  const AddRoutePage({super.key});

  @override
  State<AddRoutePage> createState() => _AddRoutePageState();
}

class _AddRoutePageState extends State<AddRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = const MockRouteRepository();

  final _nameController = TextEditingController();
  final _syndicateController = TextEditingController();
  final _lineController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fareController = TextEditingController(text: '2');
  final _hoursController = TextEditingController(text: '06:00 - 22:00');
  final _descriptionController = TextEditingController();
  final _speedController = TextEditingController(text: '18');
  final _stopsController = TextEditingController();
  final _pathController = TextEditingController();
  final _specialDaysController = TextEditingController(text: '4,7');
  final _specialDestinationController = TextEditingController();
  final _specialFareController = TextEditingController();
  final _specialPointLimitController = TextEditingController(text: '2');
  final _specialNoteController = TextEditingController();

  TransportType _transportType = TransportType.minibus;
  StreamSubscription<Position>? _positionSubscription;
  final List<LatLng> _recordedPoints = [];
  DateTime? _startedAt;
  DateTime? _endedAt;
  double _currentSpeedKmh = 0;
  bool _isRecording = false;
  bool _askedTransportConfirmation = false;
  bool _hasSpecialRule = false;

  @override
  void dispose() {
    _nameController.dispose();
    _syndicateController.dispose();
    _lineController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _fareController.dispose();
    _hoursController.dispose();
    _descriptionController.dispose();
    _speedController.dispose();
    _stopsController.dispose();
    _pathController.dispose();
    _specialDaysController.dispose();
    _specialDestinationController.dispose();
    _specialFareController.dispose();
    _specialPointLimitController.dispose();
    _specialNoteController.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    setState(() {
      _isRecording = true;
      _startedAt = DateTime.now();
      _endedAt = null;
      _recordedPoints.clear();
      _currentSpeedKmh = 0;
      _askedTransportConfirmation = false;
    });

    final initialPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _addPosition(initialPosition);

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 12,
      ),
    ).listen(_addPosition);
  }

  Future<void> _stopRecording() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    setState(() {
      _isRecording = false;
      _endedAt = DateTime.now();
      _pathController.text = _recordedPoints
          .map(
            (point) =>
                '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
          )
          .join('\n');
      if (_recordedPoints.length >= 2) {
        _speedController.text = _averageSpeedKmh().toStringAsFixed(1);
      }
    });
  }

  void _addPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    final speedKmh = (position.speed * 3.6).clamp(0, 160).toDouble();

    setState(() {
      _currentSpeedKmh = speedKmh;
      if (_recordedPoints.isEmpty ||
          GeoUtils.distanceInMeters(_recordedPoints.last, point) >= 10) {
        _recordedPoints.add(point);
      }
    });

    if (speedKmh >= 12 && !_askedTransportConfirmation && mounted) {
      _askedTransportConfirmation = true;
      _confirmTransportMode(speedKmh);
    }
  }

  Future<void> _confirmTransportMode(double speedKmh) async {
    final selectedType = await showDialog<TransportType>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Estas en transporte?'),
        content: Text(
          'Detectamos una velocidad de ${speedKmh.toStringAsFixed(1)} km/h. '
          'Puedes registrar esta ruta como transporte publico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(TransportType.micro),
            child: const Text('Micro'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(TransportType.trufi),
            child: const Text('Trufi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(TransportType.minibus),
            child: const Text('Minibus'),
          ),
        ],
      ),
    );

    if (selectedType != null && mounted) {
      setState(() => _transportType = selectedType);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Activa el GPS del telefono para grabar la ruta.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Necesitamos permiso de ubicacion para grabar la ruta.');
      return false;
    }

    return true;
  }

  Future<void> _saveRoute() async {
    if (!_formKey.currentState!.validate()) return;

    final path = _parsePath(_pathController.text);
    if (path.length < 2) {
      _showMessage('Agrega al menos dos coordenadas.');
      return;
    }

    final stops = _stopsController.text
        .split(',')
        .map((stop) => stop.trim())
        .where((stop) => stop.isNotEmpty)
        .toList();
    final specialFare = double.tryParse(_specialFareController.text.trim());

    final route = TransitRoute(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      transportType: _transportType,
      syndicate: _syndicateController.text.trim(),
      line: _lineController.text.trim(),
      origin: _originController.text.trim(),
      destination: _destinationController.text.trim(),
      fareBs: double.parse(_fareController.text.trim()),
      serviceHours: _hoursController.text.trim(),
      description: _descriptionController.text.trim(),
      averageSpeedKmh: double.parse(_speedController.text.trim()),
      stops: stops.isEmpty
          ? [_originController.text.trim(), _destinationController.text.trim()]
          : stops,
      path: path,
      fareRules: [
        FareRule(
          label: 'Tarifa base',
          destination: _destinationController.text.trim(),
          fareBs: double.parse(_fareController.text.trim()),
        ),
        if (_hasSpecialRule && specialFare != null)
          FareRule(
            label: 'Tarifa especial',
            destination: _specialDestinationController.text.trim(),
            fareBs: specialFare,
            weekdays: _parseWeekdays(_specialDaysController.text),
          ),
      ],
      scheduleRules: [
        if (_hasSpecialRule)
          RouteScheduleRule(
            name: 'Regla especial',
            weekdays: _parseWeekdays(_specialDaysController.text),
            activeDestination: _specialDestinationController.text.trim().isEmpty
                ? null
                : _specialDestinationController.text.trim(),
            pathPointLimit: int.tryParse(
              _specialPointLimitController.text.trim(),
            ),
            fareOverrideBs: specialFare,
            note: _specialNoteController.text.trim().isEmpty
                ? 'Esta ruta tiene cambios segun dia u horario.'
                : _specialNoteController.text.trim(),
          ),
      ],
    );

    await _repository.addRoute(route);

    if (!mounted) return;
    _showMessage('Ruta agregada y guardada.');
    Navigator.of(context).pop(true);
  }

  List<LatLng> _parsePath(String text) {
    final points = <LatLng>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length != 2) continue;

      final latitude = double.tryParse(parts[0].trim());
      final longitude = double.tryParse(parts[1].trim());
      if (latitude == null || longitude == null) continue;

      points.add(LatLng(latitude, longitude));
    }
    return points;
  }

  List<int> _parseWeekdays(String text) {
    return text
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value >= DateTime.monday && value <= DateTime.sunday)
        .toList();
  }

  double _averageSpeedKmh() {
    final startedAt = _startedAt;
    final endedAt = _endedAt ?? DateTime.now();
    if (startedAt == null || _recordedPoints.length < 2) return 0;

    final distanceKm =
        GeoUtils.polylineDistanceInMeters(_recordedPoints) / 1000;
    final hours = endedAt.difference(startedAt).inSeconds / 3600;
    if (hours <= 0) return 0;

    return distanceKm / hours;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar ruta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Registra un recorrido real de El Alto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Empieza con una ruta corta, por ejemplo casa a universidad. '
              'Agrega puntos donde el transporte gira o pasa por avenidas.',
            ),
            const SizedBox(height: 16),
            _RecordingPanel(
              isRecording: _isRecording,
              startedAt: _startedAt,
              endedAt: _endedAt,
              pointsCount: _recordedPoints.length,
              currentSpeedKmh: _currentSpeedKmh,
              averageSpeedKmh: _averageSpeedKmh(),
              onStart: _startRecording,
              onStop: _stopRecording,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TransportType>(
              initialValue: _transportType,
              decoration: const InputDecoration(
                labelText: 'Tipo de transporte',
                prefixIcon: Icon(Icons.commute),
              ),
              items: TransportType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _transportType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _TextField(
              controller: _nameController,
              label: 'Nombre visible',
              hint: 'Minibus Demo - Casa a UPEA',
            ),
            _TextField(
              controller: _lineController,
              label: 'Linea o numero',
              hint: '101, A, Demo',
            ),
            _TextField(
              controller: _syndicateController,
              label: 'Sindicato o cooperativa',
              hint: 'Sindicato 16 de Julio',
            ),
            _TextField(
              controller: _originController,
              label: 'Origen',
              hint: 'Zona 16 de Julio',
            ),
            _TextField(
              controller: _destinationController,
              label: 'Destino',
              hint: 'Universidad UPEA',
            ),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    controller: _fareController,
                    label: 'Tarifa Bs',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextField(
                    controller: _speedController,
                    label: 'Velocidad km/h',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            _TextField(
              controller: _hoursController,
              label: 'Horario',
              hint: '06:00 - 22:00',
            ),
            _TextField(
              controller: _descriptionController,
              label: 'Descripcion',
              hint: 'Pasa por la avenida principal y Villa Esperanza',
              maxLines: 2,
            ),
            _TextField(
              controller: _stopsController,
              label: 'Paradas separadas por coma',
              hint: 'Casa, Av. Juan Pablo II, Villa Esperanza, UPEA',
              maxLines: 2,
            ),
            _TextField(
              controller: _pathController,
              label: 'Coordenadas del recorrido',
              hint: '-16.50460, -68.17080\n-16.50180, -68.17640',
              maxLines: 6,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasSpecialRule,
              title: const Text('Agregar regla especial'),
              subtitle: const Text(
                'Usalo para feria, bloqueo, marcha, horario o trameaje.',
              ),
              onChanged: (value) => setState(() => _hasSpecialRule = value),
            ),
            if (_hasSpecialRule) ...[
              _TextField(
                controller: _specialDaysController,
                label: 'Dias de la regla',
                hint: '1=lun, 2=mar, 3=mie, 4=jue, 5=vie, 6=sab, 7=dom',
              ),
              _TextField(
                controller: _specialDestinationController,
                label: 'Destino en esos dias',
                hint: 'Plaza Ballivian salida de combis',
              ),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _specialFareController,
                      label: 'Tarifa especial Bs',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      controller: _specialPointLimitController,
                      label: 'Puntos a mostrar',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              _TextField(
                controller: _specialNoteController,
                label: 'Motivo',
                hint: 'Por feria, no llega hasta el destino final',
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Para sacar coordenadas: en Google Maps, clic derecho sobre '
              'una esquina o parada y copia latitud, longitud.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveRoute,
              icon: const Icon(Icons.save),
              label: const Text('Guardar ruta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Campo requerido';
          }
          if (keyboardType == TextInputType.number &&
              double.tryParse(value.trim()) == null) {
            return 'Ingresa un numero valido';
          }
          return null;
        },
      ),
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.isRecording,
    required this.startedAt,
    required this.endedAt,
    required this.pointsCount,
    required this.currentSpeedKmh,
    required this.averageSpeedKmh,
    required this.onStart,
    required this.onStop,
  });

  final bool isRecording;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int pointsCount;
  final double currentSpeedKmh;
  final double averageSpeedKmh;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final started = startedAt;
    final ended = endedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Grabar recorrido con GPS',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Presiona iniciar cuando subas al transporte y terminar cuando '
              'bajes. La app guardara hora, dia, puntos y velocidad.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Puntos: $pointsCount')),
                Chip(
                  label: Text(
                    'Velocidad: ${currentSpeedKmh.toStringAsFixed(1)} km/h',
                  ),
                ),
                Chip(
                  label: Text(
                    'Promedio: ${averageSpeedKmh.toStringAsFixed(1)} km/h',
                  ),
                ),
              ],
            ),
            if (started != null) ...[
              const SizedBox(height: 8),
              Text('Inicio: ${_formatDateTime(started)}'),
            ],
            if (ended != null) Text('Fin: ${_formatDateTime(ended)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isRecording ? null : onStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRecording ? onStop : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Terminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
