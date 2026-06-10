import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import 'route_recording_controller.dart';

const _causeOptions = [
  'Feria',
  'Bloqueo/marcha',
  'Hora pico',
  'Feriado',
  'Trameaje',
  'Otro',
];

class AddRoutePage extends StatefulWidget {
  const AddRoutePage({super.key});

  @override
  State<AddRoutePage> createState() => _AddRoutePageState();
}

class _AddRoutePageState extends State<AddRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _recordingController = RouteRecordingController();

  final _nameController = TextEditingController();
  final _syndicateController = TextEditingController();
  final _lineController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fareController = TextEditingController(text: '2');
  final _hoursController = TextEditingController(text: '06:00 - 22:00');
  final _descriptionController = TextEditingController();
  final _stopsController = TextEditingController();
  final _pathController = TextEditingController();
  final _specialStartHourController = TextEditingController(text: '0');
  final _specialEndHourController = TextEditingController(text: '23');
  final _specialDestinationController = TextEditingController();
  final _specialFareController = TextEditingController();
  final _specialCauseController = TextEditingController();
  final _specialNoteController = TextEditingController();

  TransportType _transportType = TransportType.minibus;
  bool _hasSpecialRule = false;
  Set<int> _selectedDays = {};
  String? _selectedCause;

  @override
  void initState() {
    super.initState();
    _recordingController.addListener(_onRecordingUpdate);
  }

  @override
  void dispose() {
    _recordingController.removeListener(_onRecordingUpdate);
    _recordingController.dispose();
    _nameController.dispose();
    _syndicateController.dispose();
    _lineController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _fareController.dispose();
    _hoursController.dispose();
    _descriptionController.dispose();
    _stopsController.dispose();
    _pathController.dispose();
    _specialStartHourController.dispose();
    _specialEndHourController.dispose();
    _specialDestinationController.dispose();
    _specialFareController.dispose();
    _specialCauseController.dispose();
    _specialNoteController.dispose();
    super.dispose();
  }

  void _onRecordingUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _startRecording() async {
    final result = await _recordingController.start();
    if (!mounted) return;
    switch (result) {
      case RouteRecordingStartResult.locationServiceDisabled:
        _showMessage('Activa el GPS del telefono para grabar la ruta.');
      case RouteRecordingStartResult.permissionDenied:
        _showMessage('Necesitamos permiso de ubicacion para grabar la ruta.');
      case RouteRecordingStartResult.alreadyRecording:
      case RouteRecordingStartResult.started:
        break;
    }
  }

  Future<void> _stopRecording() async {
    await _recordingController.stop();
    if (!mounted) return;
    final startedAt = _recordingController.startedAt;
    final endedAt = _recordingController.endedAt;
    setState(() {
      _pathController.text = _recordingController.recordedPoints
          .map(
            (p) =>
                '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}',
          )
          .join('\n');
      if (startedAt != null && endedAt != null) {
        _hoursController.text =
            '${_formatHourMinute(startedAt)} - ${_formatHourMinute(endedAt)}';
      }
    });
  }

  void _onVariationToggled(bool value) {
    setState(() {
      _hasSpecialRule = value;
      if (value) {
        if (_selectedDays.isEmpty) {
          final day =
              _recordingController.startedAt?.weekday ??
              DateTime.now().weekday;
          _selectedDays = {day};
        }
        final startedAt = _recordingController.startedAt;
        final endedAt = _recordingController.endedAt;
        if (startedAt != null) {
          _specialStartHourController.text = startedAt.hour.toString();
        }
        if (endedAt != null) {
          _specialEndHourController.text = endedAt.hour.toString();
        }
      }
    });
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
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final now = DateTime.now();
    final syndicate = _syndicateController.text.trim().isEmpty
        ? 'Desconocido'
        : _syndicateController.text.trim();
    final line = _lineController.text.trim().isEmpty
        ? 'Desconocido'
        : _lineController.text.trim();

    final specialStartHour = _parseHour(_specialStartHourController.text);
    final specialEndHour = _parseHour(_specialEndHourController.text);
    final specialFare = double.tryParse(_specialFareController.text.trim());
    final causeText = _selectedCause == 'Otro'
        ? _specialCauseController.text.trim()
        : (_selectedCause ?? '');
    final specialNote = _specialNoteController.text.trim();
    final variationReason = causeText.isEmpty
        ? specialNote
        : [causeText, if (specialNote.isNotEmpty) specialNote].join(': ');
    final weekdays = _selectedDays.toList()..sort();

    final route = TransitRoute(
      id: 'manual-${now.millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      transportType: _transportType,
      syndicate: syndicate,
      line: line,
      origin: _originController.text.trim(),
      destination: _destinationController.text.trim(),
      fareBs: double.parse(_fareController.text.trim()),
      serviceHours: _hoursController.text.trim(),
      description: _descriptionController.text.trim(),
      averageSpeedKmh: _recordingController.averageSpeedForSaving,
      stops: stops.isEmpty
          ? [_originController.text.trim(), _destinationController.text.trim()]
          : stops,
      path: path,
      createdAt: now,
      recordedStartedAt: _recordingController.startedAt,
      recordedEndedAt: _recordingController.endedAt ?? now,
      variationReason: _hasSpecialRule ? variationReason : '',
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
            weekdays: weekdays,
            startHour: specialStartHour,
            endHour: specialEndHour,
          ),
      ],
      scheduleRules: [
        if (_hasSpecialRule)
          RouteScheduleRule(
            name: 'Regla especial',
            weekdays: weekdays,
            activeDestination:
                _specialDestinationController.text.trim().isEmpty
                    ? null
                    : _specialDestinationController.text.trim(),
            startHour: specialStartHour,
            endHour: specialEndHour,
            fareOverrideBs: specialFare,
            note: variationReason.isEmpty
                ? 'Esta ruta tiene cambios segun dia u horario.'
                : variationReason,
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

  int _parseHour(String text) {
    final hour = int.tryParse(text.trim()) ?? 0;
    return hour.clamp(0, 23).toInt();
  }

  String _formatHourMinute(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              isRecording: _recordingController.isRecording,
              startedAt: _recordingController.startedAt,
              endedAt: _recordingController.endedAt,
              recordedPoints: _recordingController.recordedPoints,
              distanceMeters: _recordingController.distanceMeters,
              currentSpeedKmh: _recordingController.currentSpeedKmh,
              averageSpeedKmh: _recordingController.averageSpeedKmh,
              onStart: _startRecording,
              onStop: _stopRecording,
            ),
            const SizedBox(height: 8),
            const _SectionHeader('Informacion basica'),
            DropdownButtonFormField<TransportType>(
              initialValue: _transportType,
              decoration: InputDecoration(
                labelText: 'Tipo de transporte',
                prefixIcon: PhosphorIcon(PhosphorIcons.path()),
              ),
              items: TransportType.values
                  .map(
                    (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _transportType = value);
              },
            ),
            const SizedBox(height: 12),
            _TextField(
              controller: _nameController,
              label: 'Nombre de la ruta',
              hint: 'Ej: Minibus 101 - Ceja a Villa Adela',
              helperText:
                  'Nombre que vera el pasajero en la lista. Incluye numero de linea y recorrido.',
            ),
            _TextField(
              controller: _lineController,
              label: 'Linea o numero',
              hint: '101, A, 204',
              required: false,
            ),
            _TextField(
              controller: _syndicateController,
              label: 'Sindicato o cooperativa',
              hint: 'Sindicato 16 de Julio',
              required: false,
              helperText: 'Opcional. Si no hay letrero visible deja este campo vacio.',
            ),
            const _SectionHeader('Recorrido'),
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
            const _SectionHeader('Tarifa y horario'),
            _TextField(
              controller: _fareController,
              label: 'Pasaje normal Bs',
              keyboardType: TextInputType.number,
            ),
            _TextField(
              controller: _hoursController,
              label: 'Horario de servicio',
              hint: '06:00 - 22:00',
              helperText:
                  'Hora del primer y ultimo transporte del dia. Se llena automaticamente al grabar, ajusta si conoces el horario real.',
            ),
            _TextField(
              controller: _descriptionController,
              label: 'Descripcion',
              hint: 'Pasa por la avenida principal y Villa Esperanza',
              maxLines: 2,
              required: false,
              helperText:
                  'Opcional. Referencias utiles para el pasajero.',
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
              helperText:
                  'Se llena automaticamente al grabar. O copia coordenadas desde Google Maps (clic derecho sobre el punto).',
            ),
            const _SectionHeader('Variacion especial'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasSpecialRule,
              title: const Text('Agregar variacion de pasaje o recorrido'),
              subtitle: const Text(
                'Activa si la ruta cambia en ciertos dias u horarios: feria, bloqueo, hora pico, feriado.',
              ),
              onChanged: _onVariationToggled,
            ),
            if (_hasSpecialRule) ...[
              const SizedBox(height: 4),
              Text(
                'Dias donde aplica la variacion',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _DayChipSelector(
                selectedDays: _selectedDays,
                onChanged: (days) => setState(() => _selectedDays = days),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _specialStartHourController,
                      label: 'Desde hora',
                      hint: '7',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      controller: _specialEndHourController,
                      label: 'Hasta hora',
                      hint: '10',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _selectedCause, // ignore: deprecated_member_use
                  decoration: const InputDecoration(labelText: 'Causa'),
                  items: _causeOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCause = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una causa' : null,
                ),
              ),
              if (_selectedCause == 'Otro')
                _TextField(
                  controller: _specialCauseController,
                  label: 'Describe la causa',
                  hint: 'Ej: Cierre de via por construccion',
                ),
              _TextField(
                controller: _specialDestinationController,
                label: 'Destino en esos dias',
                hint: 'Plaza Ballivian salida de combis',
                required: false,
              ),
              _TextField(
                controller: _specialFareController,
                label: 'Tarifa especial Bs',
                keyboardType: TextInputType.number,
                required: false,
              ),
              _TextField(
                controller: _specialNoteController,
                label: 'Detalle observado',
                hint: 'No llega hasta destino final o cobra otro pasaje',
                maxLines: 2,
                required: false,
                helperText:
                    'Opcional. Cualquier detalle que ayude a entender la variacion.',
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveRoute,
              icon: PhosphorIcon(PhosphorIcons.floppyDisk()),
              label: const Text('Guardar ruta'),
            ),
            const SizedBox(height: 16),
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
    this.helperText,
    this.maxLines = 1,
    this.keyboardType,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helperText;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperMaxLines: 3,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return 'Campo requerido';
          if (text.isEmpty) return null;
          if (keyboardType == TextInputType.number &&
              double.tryParse(text) == null) {
            return 'Ingresa un numero valido';
          }
          return null;
        },
      ),
    );
  }
}

class _DayChipSelector extends StatelessWidget {
  const _DayChipSelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onChanged;

  static const _labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _tooltips = [
    'Lunes',
    'Martes',
    'Miercoles',
    'Jueves',
    'Viernes',
    'Sabado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = selectedDays.contains(day);
        return Tooltip(
          message: _tooltips[i],
          child: FilterChip(
            label: Text(_labels[i]),
            selected: isSelected,
            onSelected: (selected) {
              final next = Set<int>.from(selectedDays);
              if (selected) {
                next.add(day);
              } else if (next.length > 1) {
                next.remove(day);
              }
              onChanged(next);
            },
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}

class _RecordingPanel extends StatefulWidget {
  const _RecordingPanel({
    required this.isRecording,
    required this.startedAt,
    required this.endedAt,
    required this.recordedPoints,
    required this.distanceMeters,
    required this.currentSpeedKmh,
    required this.averageSpeedKmh,
    required this.onStart,
    required this.onStop,
  });

  final bool isRecording;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<LatLng> recordedPoints;
  final double distanceMeters;
  final double currentSpeedKmh;
  final double averageSpeedKmh;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  State<_RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<_RecordingPanel> {
  static const _elAltoCenter = LatLng(-16.5046, -68.1730);
  final _mapController = MapController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.isRecording) _startTicker();
  }

  @override
  void didUpdateWidget(_RecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording != oldWidget.isRecording) {
      widget.isRecording ? _startTicker() : _stopTicker();
    }

    final points = widget.recordedPoints;
    if (points.isNotEmpty) {
      final oldLast = oldWidget.recordedPoints.isNotEmpty
          ? oldWidget.recordedPoints.last
          : null;
      if (points.last != oldLast) {
        _mapController.move(points.last, 16);
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  String _formatElapsed() {
    final start = widget.startedAt;
    if (start == null) return '00:00';
    final end = widget.endedAt ?? DateTime.now();
    final elapsed = end.difference(start);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatDistance() {
    final m = widget.distanceMeters;
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final started = widget.startedAt;
    final ended = widget.endedAt;
    final referenceEnd = ended ?? DateTime.now();
    final duration = started == null ? null : referenceEnd.difference(started);
    final points = widget.recordedPoints;
    final lastPoint = points.isNotEmpty ? points.last : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _elAltoCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mi_app',
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (lastPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: lastPoint,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: widget.isRecording
                                ? Colors.green
                                : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.crosshair(PhosphorIconsStyle.fill)),
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
                  'bajes. La app guardara automaticamente dia, hora, puntos y velocidad.',
                ),
                const SizedBox(height: 12),
                _AutoRecordingSummary(
                  startedAt: started,
                  endedAt: ended,
                  duration: duration,
                  averageSpeedKmh: widget.averageSpeedKmh,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (started != null) ...[
                      Chip(
                        avatar: PhosphorIcon(PhosphorIcons.timer(), size: 16),
                        label: Text(_formatElapsed()),
                      ),
                      Chip(
                        avatar: PhosphorIcon(PhosphorIcons.ruler(), size: 16),
                        label: Text(_formatDistance()),
                      ),
                    ],
                    Chip(label: Text('Puntos: ${points.length}')),
                    Chip(
                      label: Text(
                        'Vel: ${widget.currentSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Prom: ${widget.averageSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.isRecording ? null : widget.onStart,
                        icon: PhosphorIcon(PhosphorIcons.play(PhosphorIconsStyle.fill)),
                        label: const Text('Iniciar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.isRecording ? widget.onStop : null,
                        icon: PhosphorIcon(PhosphorIcons.stop(PhosphorIconsStyle.fill)),
                        label: const Text('Terminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRecordingSummary extends StatelessWidget {
  const _AutoRecordingSummary({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.averageSpeedKmh,
  });

  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration? duration;
  final double averageSpeedKmh;

  @override
  Widget build(BuildContext context) {
    final started = startedAt;
    final ended = endedAt;
    final elapsed = duration;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Datos automaticos de grabacion',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            started == null
                ? 'Inicio: se registrara al presionar Iniciar'
                : 'Inicio: ${_formatDateTime(started)}',
          ),
          Text(
            ended == null
                ? 'Fin: se registrara al presionar Terminar'
                : 'Fin: ${_formatDateTime(ended)}',
          ),
          Text(
            elapsed == null
                ? 'Duracion: pendiente'
                : 'Duracion: ${_formatDuration(elapsed)}',
          ),
          Text(
            averageSpeedKmh <= 0
                ? 'Velocidad promedio: pendiente'
                : 'Velocidad promedio: ${averageSpeedKmh.toStringAsFixed(1)} km/h',
          ),
        ],
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

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
