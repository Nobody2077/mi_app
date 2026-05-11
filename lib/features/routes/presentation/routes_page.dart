import 'package:flutter/material.dart';

import '../data/mock_route_repository.dart';
import '../domain/models/transit_route.dart';
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
  final _repository = const MockRouteRepository();
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
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar ruta'),
                  ),
                );
              }

              final route = savedRoutes[index - 2];
              return RouteCard(
                route: route,
                estimatedArrival: _etaService.estimateArrival(route),
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
}
