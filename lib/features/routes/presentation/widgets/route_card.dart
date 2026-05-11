import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/transit_route.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({
    required this.route,
    required this.estimatedArrival,
    required this.onOpenMap,
    super.key,
  });

  final TransitRoute route;
  final Duration estimatedArrival;
  final VoidCallback onOpenMap;

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
            const SizedBox(height: 8),
            Text(route.description),
            const SizedBox(height: 8),
            Text('Llegada estimada: ${estimatedArrival.inMinutes} min'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver mapa'),
              ),
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
}
