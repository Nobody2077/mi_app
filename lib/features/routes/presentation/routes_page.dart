import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/route_export_service.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/services/eta_service.dart';
import 'add_route_page.dart';
import 'map_page.dart';
import 'widgets/route_card.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  final _exportService = const RouteExportService();
  final _etaService = const EtaService();

  late Future<List<TransitRoute>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _repository.getSavedRoutes();
  }

  void _reload() {
    setState(() {
      _routesFuture = _repository.getSavedRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas guardadas')),
      body: FutureBuilder<List<TransitRoute>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedRoutes = snapshot.data ?? [];

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: savedRoutes.length + 2,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tus rutas frecuentes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Guarda aqui las rutas que usas seguido, como casa '
                          'a universidad o casa a trabajo.',
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (index == 1) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AddRoutePage()),
                      );
                      _reload();
                    },
                    icon: PhosphorIcon(PhosphorIcons.plus()),
                    label: const Text('Agregar ruta'),
                  ),
                );
              }

              final route = savedRoutes[index - 2];
              return RouteCard(
                route: route,
                estimatedArrival: _etaService.estimateArrival(route),
                onExport: () => _exportRoute(route),
                onDelete: () => _confirmDeleteRoute(route),
                onOpenMap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapPage(initialRouteId: route.id),
                    ),
                  );
                },
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
      sharePositionOrigin: box == null
          ? Rect.zero
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _confirmDeleteRoute(TransitRoute route) async {
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
            icon: PhosphorIcon(PhosphorIcons.trash()),
            label: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await _repository.deleteRoute(route.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ruta borrada.')));
  }
}
