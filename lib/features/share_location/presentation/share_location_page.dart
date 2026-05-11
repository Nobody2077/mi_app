import 'package:flutter/material.dart';

import '../../routes/data/mock_route_repository.dart';
import '../../routes/domain/models/route_report.dart';
import '../../routes/domain/models/transit_route.dart';

class ShareLocationPage extends StatefulWidget {
  const ShareLocationPage({super.key});

  @override
  State<ShareLocationPage> createState() => _ShareLocationPageState();
}

class _ShareLocationPageState extends State<ShareLocationPage> {
  final _repository = const MockRouteRepository();
  final _commentController = TextEditingController();

  List<TransitRoute> _routes = [];
  TransitRoute? _selectedRoute;
  ReportType _reportType = ReportType.routeChanged;
  bool _isSharing = false;
  bool _routeIsCorrect = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final routes = await _repository.getRoutes();
    setState(() {
      _routes = routes;
      _selectedRoute = routes.isEmpty ? null : routes.first;
    });
  }

  Future<void> _sendReport() async {
    final selectedRoute = _selectedRoute;
    if (selectedRoute == null) return;

    final comment = _commentController.text.trim().isEmpty
        ? (_routeIsCorrect
              ? 'El usuario confirma que la ruta sigue igual.'
              : 'El usuario reporta que la ruta no sigue igual.')
        : _commentController.text.trim();

    await _repository.addReport(
      RouteReport(
        id: 'report-${DateTime.now().millisecondsSinceEpoch}',
        routeId: selectedRoute.id,
        type: _reportType,
        comment: comment,
        createdAt: DateTime.now(),
      ),
    );

    _commentController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dato colaborativo registrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir ubicacion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Colabora con datos de transporte',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Para el prototipo se simula el envio de ubicacion. Despues se '
            'conectara GPS real con permisos del usuario.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRoute?.id,
            decoration: const InputDecoration(
              labelText: 'Estoy en esta ruta',
              prefixIcon: Icon(Icons.alt_route),
            ),
            items: _routes
                .map(
                  (route) => DropdownMenuItem(
                    value: route.id,
                    child: Text(route.name),
                  ),
                )
                .toList(),
            onChanged: (routeId) {
              if (routeId == null) return;
              setState(() {
                _selectedRoute = _routes.firstWhere(
                  (route) => route.id == routeId,
                );
              });
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isSharing,
            title: const Text('Enviar ubicacion colaborativa'),
            subtitle: Text(
              _isSharing
                  ? 'Simulando envio de posicion del pasajero.'
                  : 'Activa solo si estas dentro del transporte.',
            ),
            secondary: const Icon(Icons.my_location),
            onChanged: (value) {
              setState(() => _isSharing = value);
            },
          ),
          CheckboxListTile(
            value: _routeIsCorrect,
            title: const Text('La ruta sigue el recorrido esperado'),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) {
              setState(() => _routeIsCorrect = value ?? true);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportType>(
            initialValue: _reportType,
            decoration: const InputDecoration(
              labelText: 'Tipo de dato colaborativo',
              prefixIcon: Icon(Icons.report_outlined),
            ),
            items: ReportType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _reportType = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario opcional',
              hintText: 'Ej. esta desviando por otra avenida',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sendReport,
            icon: const Icon(Icons.send),
            label: const Text('Enviar dato'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSharing ? 'Estado: activo' : 'Estado: inactivo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estos datos serviran para estimar tiempos, detectar '
                    'desvios y validar recorridos reales.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
