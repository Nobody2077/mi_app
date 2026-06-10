import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../app/app_theme.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import 'route_detail_page.dart';

class AvailableNowPage extends StatefulWidget {
  const AvailableNowPage({super.key});

  @override
  State<AvailableNowPage> createState() => _AvailableNowPageState();
}

class _AvailableNowPageState extends State<AvailableNowPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;
  List<TransitRoute> _available = [];
  bool _loading = true;
  late DateTime _loadedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final routes = await _repository.getRoutes();
    if (!mounted) return;
    setState(() {
      _loadedAt = now;
      _available = routes
          .where(
            (r) =>
                r.scheduleRules.isEmpty ||
                r.scheduleRules.any((rule) => rule.appliesAt(now)),
          )
          .toList();
      _loading = false;
    });
  }

  String get _timeLabel {
    final h = _loadedAt.hour.toString().padLeft(2, '0');
    final m = _loadedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibles ahora')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _available.isEmpty
              ? const _EmptyAvailable()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.clock(),
                            size: 15,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_available.length} líneas activas a las $_timeLabel',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _available.length,
                        itemBuilder: (context, index) {
                          final route = _available[index];
                          final color = _colorFor(route.transportType);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _iconFor(route.transportType),
                                  color: color,
                                ),
                              ),
                              title: Text(route.name),
                              subtitle: Text(
                                '${route.origin} → ${route.destination}',
                              ),
                              trailing: PhosphorIcon(
                                PhosphorIcons.caretRight(),
                                size: 16,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RouteDetailPage(route: route),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Color _colorFor(TransportType type) => switch (type) {
        TransportType.minibus => AppTheme.minibus,
        TransportType.trufi => AppTheme.trufi,
        TransportType.micro => AppTheme.micro,
      };

  IconData _iconFor(TransportType type) => switch (type) {
        TransportType.minibus => PhosphorIcons.van(),
        TransportType.trufi => PhosphorIcons.taxi(),
        TransportType.micro => PhosphorIcons.bus(),
      };
}

class _EmptyAvailable extends StatelessWidget {
  const _EmptyAvailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.clock(),
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin líneas disponibles ahora',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay rutas con horario registrado para este momento del día.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
