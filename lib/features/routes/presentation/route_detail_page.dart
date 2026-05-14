import 'package:flutter/material.dart';

import '../data/route_export_service.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/route_report.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/eta_service.dart';
import '../domain/services/route_availability_service.dart';
import 'map_page.dart';

class RouteDetailPage extends StatefulWidget {
  const RouteDetailPage({required this.route, super.key});

  final TransitRoute route;

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _exportService = const RouteExportService();
  final _etaService = const EtaService();
  final _availabilityService = const RouteAvailabilityService();

  bool _isSaved = false;
  List<RouteReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final isSaved = await _repository.isRouteSaved(widget.route.id);
    final reports = await _repository.getReports(widget.route.id);

    if (!mounted) return;
    setState(() {
      _isSaved = isSaved;
      _reports = reports;
    });
  }

  Future<void> _toggleSaved() async {
    await _repository.toggleSavedRoute(widget.route.id);
    await _loadState();
  }

  Future<void> _showReportDialog() async {
    final report = await showDialog<RouteReport>(
      context: context,
      builder: (_) => _ReportDialog(routeId: widget.route.id),
    );

    if (report == null) return;

    await _repository.addReport(report);
    await _loadState();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reporte registrado.')));
  }

  Future<void> _exportRoute() async {
    final box = context.findRenderObject() as RenderBox?;
    await _exportService.shareRoute(
      route: widget.route,
      reports: _reports,
      sharePositionOrigin: box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _confirmDeleteRoute() async {
    final route = widget.route;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar ruta'),
        content: Text(
          'Se borrara "${route.name}" de este dispositivo. Esta accion no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await _repository.deleteRoute(route.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final eta = _etaService.estimateArrival(route);
    final activeInfo = _availabilityService.evaluate(route, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de ruta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(route.transportType), size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          route.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('${route.origin} -> ${route.destination}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(route.transportType.label)),
                      Chip(label: Text('Linea ${route.line}')),
                      Chip(label: Text(route.syndicate)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Tarifa: Bs ${route.fareBs.toStringAsFixed(1)}'),
                  Text(
                    'Tarifa actual: Bs ${activeInfo.fareBs.toStringAsFixed(1)}',
                  ),
                  Text('Horario: ${route.serviceHours}'),
                  Text('Tiempo estimado: ${eta.inMinutes} min'),
                  Text(
                    route.isOfficial ? 'Ruta oficial' : 'Ruta no verificada',
                  ),
                  if (route.recordedStartedAt != null)
                    Text(
                      'Grabacion: ${_formatDateTime(route.recordedStartedAt!)}',
                    ),
                  if (route.recordedEndedAt != null)
                    Text('Fin: ${_formatDateTime(route.recordedEndedAt!)}'),
                  if (route.variationReason.isNotEmpty)
                    Text('Causa observada: ${route.variationReason}'),
                  const SizedBox(height: 12),
                  Text(route.description),
                  const SizedBox(height: 12),
                  Text(
                    activeInfo.isModified
                        ? 'Hoy: ${activeInfo.note}'
                        : activeInfo.note,
                    style: TextStyle(
                      color: activeInfo.isModified
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (route.fareRules.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarifas por tramo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final rule in route.fareRules)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(rule.label),
                        subtitle: Text(rule.destination),
                        trailing: Text('Bs ${rule.fareBs.toStringAsFixed(1)}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paradas principales',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final stop in route.stops)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(stop),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MapPage(initialRouteId: route.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver mapa'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: _isSaved ? 'Quitar guardado' : 'Guardar ruta',
                onPressed: _toggleSaved,
                icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showReportDialog,
            icon: const Icon(Icons.report_outlined),
            label: const Text('Reportar cambio o problema'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportRoute,
            icon: const Icon(Icons.ios_share),
            label: const Text('Exportar o compartir ruta'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmDeleteRoute,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Borrar ruta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          if (_reports.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes recientes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final report in _reports.reversed.take(3))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.info_outline),
                        title: Text(report.type.label),
                        subtitle: Text(report.comment),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(TransportType type) {
    return switch (type) {
      TransportType.minibus => Icons.airport_shuttle,
      TransportType.trufi => Icons.local_taxi,
      TransportType.micro => Icons.directions_bus,
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

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.routeId});

  final String routeId;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _commentController = TextEditingController();
  ReportType _type = ReportType.routeChanged;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar ruta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ReportType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo de reporte'),
            items: ReportType.values
                .map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario',
              hintText: 'Ej. hoy esta desviando por otra avenida',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final comment = _commentController.text.trim();
            if (comment.isEmpty) return;

            Navigator.of(context).pop(
              RouteReport(
                id: 'report-${DateTime.now().millisecondsSinceEpoch}',
                routeId: widget.routeId,
                type: _type,
                comment: comment,
                createdAt: DateTime.now(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
