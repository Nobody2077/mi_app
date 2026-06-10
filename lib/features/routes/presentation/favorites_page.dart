import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../app/app_theme.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/eta_service.dart';
import 'passenger_map_page.dart';
import 'route_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _etaService = const EtaService();

  late Future<List<TransitRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getSavedRoutes();
  }

  void _reload() => setState(() {
        _routesFuture = _repository.getSavedRoutes();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutas favoritas')),
      body: FutureBuilder<List<TransitRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data ?? [];
          if (routes.isEmpty) return const _EmptyFavorites();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final route = routes[index];
              return _FavoriteRouteCard(
                route: route,
                estimatedArrival: _etaService.estimateArrival(route),
                onRemove: () => _confirmRemove(route),
                onOpenDetail: () => _openDetail(route),
                onOpenMap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PassengerMapPage(initialRouteId: route.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openDetail(TransitRoute route) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteDetailPage(route: route)),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _confirmRemove(TransitRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar de favoritos'),
        content: Text(
          'Se quitará "${route.name}" de tus favoritos. '
          'La ruta seguirá disponible en la búsqueda y el mapa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: PhosphorIcon(PhosphorIcons.starHalf()),
            label: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _repository.toggleSavedRoute(route.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ruta quitada de favoritos.')),
    );
  }
}

class _FavoriteRouteCard extends StatelessWidget {
  const _FavoriteRouteCard({
    required this.route,
    required this.estimatedArrival,
    required this.onRemove,
    required this.onOpenDetail,
    required this.onOpenMap,
  });

  final TransitRoute route;
  final Duration estimatedArrival;
  final VoidCallback onRemove;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(route.transportType);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconFor(route.transportType), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${route.origin} → ${route.destination}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar de favoritos',
                    onPressed: onRemove,
                    icon: PhosphorIcon(
                      PhosphorIcons.star(PhosphorIconsStyle.fill),
                      color: AppTheme.micro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Bs ${route.fareBs.toStringAsFixed(1)}')),
                  Chip(
                    avatar: PhosphorIcon(
                      PhosphorIcons.clock(),
                      size: 16,
                      color: color,
                    ),
                    label: Text('${estimatedArrival.inMinutes} min'),
                  ),
                  Chip(label: Text(route.transportType.label)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenMap,
                  icon: PhosphorIcon(PhosphorIcons.mapTrifold()),
                  label: const Text('Ver en mapa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(TransportType type) {
    return switch (type) {
      TransportType.minibus => PhosphorIcons.van(),
      TransportType.trufi => PhosphorIcons.taxi(),
      TransportType.micro => PhosphorIcons.bus(),
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

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.star(),
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin rutas favoritas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Busca una ruta y toca el ★ en el detalle para guardarla aquí.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
              label: const Text('Buscar rutas'),
            ),
          ],
        ),
      ),
    );
  }
}
