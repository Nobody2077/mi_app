import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/route_export_service.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/eta_service.dart';
import 'map_page.dart';
import 'widgets/route_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _exportService = const RouteExportService();
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
              return RouteCard(
                route: route,
                estimatedArrival: _etaService.estimateArrival(route),
                onExport: () => _exportRoute(route),
                onDelete: () => _confirmRemove(route),
                onOpenMap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapPage(initialRouteId: route.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _exportRoute(TransitRoute route) async {
    final box = context.findRenderObject() as RenderBox?;
    final reports = await _repository.getReports(route.id);
    if (!mounted) return;
    await _exportService.shareRoute(
      route: route,
      reports: reports,
      sharePositionOrigin:
          box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _confirmRemove(TransitRoute route) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar de favoritos'),
        content: Text('Se quitará "${route.name}" de tus favoritos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: PhosphorIcon(PhosphorIcons.trash()),
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
