import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/transit_route.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    required this.route,
    required this.estimatedArrival,
    required this.onOpenMap,
    required this.onExport,
    required this.onDelete,
    super.key,
  });

  final TransitRoute route;
  final Duration estimatedArrival;
  final VoidCallback onOpenMap;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colorFor(
                      route.transportType,
                    ).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconFor(route.transportType),
                    color: _colorFor(route.transportType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('${route.origin} -> ${route.destination}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    _iconFor(route.transportType),
                    size: 16,
                    color: _colorFor(route.transportType),
                  ),
                  label: Text(route.transportType.label),
                ),
                Chip(label: Text('Linea ${route.line}')),
                Chip(label: Text(route.syndicate)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Paradas: ${route.stops.join(', ')}'),
            const SizedBox(height: 8),
            Text('Tarifa: Bs ${route.fareBs.toStringAsFixed(1)}'),
            const SizedBox(height: 8),
            Text('Horario: ${route.serviceHours}'),
            if (route.recordedStartedAt != null) ...[
              const SizedBox(height: 8),
              Text('Grabada: ${_formatDateTime(route.recordedStartedAt!)}'),
            ],
            if (route.variationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Observacion: ${route.variationReason}'),
            ],
            const SizedBox(height: 8),
            Text(route.description),
            const SizedBox(height: 8),
            Text('Llegada estimada: ${estimatedArrival.inMinutes} min'),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Exportar'),
                ),
                TextButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Mapa'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Borrar ruta',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
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
