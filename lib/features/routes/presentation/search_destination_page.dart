import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../app/app_assets.dart';
import '../data/route_repository_provider.dart';
import '../domain/models/transit_route.dart';
import '../domain/repositories/route_repository.dart';
import 'route_detail_page.dart';

class SearchDestinationPage extends StatefulWidget {
  const SearchDestinationPage({super.key});

  @override
  State<SearchDestinationPage> createState() => _SearchDestinationPageState();
}

class _SearchDestinationPageState extends State<SearchDestinationPage> {
  final RouteRepository _repository = RouteRepositoryProvider.instance;

  List<TransitRoute> _routes = [];
  List<TransitRoute> _filteredRoutes = [];
  TransportType? _selectedTransportType;
  String _originQuery = '';
  String _destinationQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  bool get _hasQuery => _originQuery.isNotEmpty || _destinationQuery.isNotEmpty;

  Future<void> _loadRoutes() async {
    final routes = await _repository.getRoutes();
    setState(() {
      _routes = routes;
      _filteredRoutes = [];
    });
  }

  void _searchOrigin(String value) {
    _originQuery = value.trim().toLowerCase();
    _applyFilters();
  }

  void _searchDestination(String value) {
    _destinationQuery = value.trim().toLowerCase();
    _applyFilters();
  }

  void _selectTransportType(TransportType? type) {
    _selectedTransportType = type;
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredRoutes = _routes.where((route) {
        final matchesTransport =
            _selectedTransportType == null ||
            route.transportType == _selectedTransportType;
        final originText = [
          route.origin,
          ...route.stops,
        ].join(' ').toLowerCase();
        final destinationText = [
          route.destination,
          ...route.stops,
        ].join(' ').toLowerCase();
        final matchesOrigin =
            _originQuery.isEmpty || originText.contains(_originQuery);
        final matchesDestination =
            _destinationQuery.isEmpty ||
            destinationText.contains(_destinationQuery);

        return matchesTransport && matchesOrigin && matchesDestination;
      }).toList();
    });
  }

  Iterable<String> _originSuggestions(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final values = <String>{};
    for (final route in _routes.where(
      (route) =>
          _selectedTransportType == null ||
          route.transportType == _selectedTransportType,
    )) {
      values.add(route.origin);
      values.addAll(route.stops);
    }

    return values.where((value) => value.toLowerCase().contains(query)).take(8);
  }

  Iterable<String> _destinationSuggestions(String text) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final values = <String>{};
    for (final route in _routes.where(
      (route) =>
          _selectedTransportType == null ||
          route.transportType == _selectedTransportType,
    )) {
      values.add(route.destination);
      values.addAll(route.stops);
    }

    return values.where((value) => value.toLowerCase().contains(query)).take(8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar destino')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Autocomplete<String>(
                  optionsBuilder: (value) => _originSuggestions(value.text),
                  onSelected: _searchOrigin,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: _searchOrigin,
                          onSubmitted: (_) => onFieldSubmitted(),
                          decoration: InputDecoration(
                            labelText: 'Estoy en...',
                            prefixIcon: PhosphorIcon(PhosphorIcons.crosshair()),
                          ),
                        );
                      },
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (value) => _destinationSuggestions(value.text),
                  onSelected: _searchDestination,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: _searchDestination,
                          onSubmitted: (_) => onFieldSubmitted(),
                          decoration: InputDecoration(
                            labelText: 'Quiero ir a...',
                            prefixIcon: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
                          ),
                        );
                      },
                ),
              ],
            ),
          ),
          if (_hasQuery) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Resultados',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _selectedTransportType == null,
                      onSelected: (_) => _selectTransportType(null),
                    ),
                  ),
                  for (final type in TransportType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(_iconFor(type), size: 16),
                        showCheckmark: false,
                        label: Text(type.label),
                        selected: _selectedTransportType == type,
                        onSelected: (_) => _selectTransportType(type),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredRoutes.isEmpty
                  ? const _NoRoutesFound()
                  : ListView.builder(
                      itemCount: _filteredRoutes.length,
                      itemBuilder: (context, index) {
                        final route = _filteredRoutes[index];
                        return ListTile(
                          leading: Icon(_iconFor(route.transportType)),
                          title: Text(route.name),
                          subtitle: Text(
                            '${route.transportType.label} ${route.line} - '
                            '${route.stops.join(' -> ')}',
                          ),
                          trailing: PhosphorIcon(PhosphorIcons.caretRight()),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RouteDetailPage(route: route),
                              ),
                            );
                            await _loadRoutes();
                          },
                        );
                      },
                    ),
            ),
          ] else
            const Expanded(child: _SearchHint()),
        ],
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
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppAssets.mascot, width: 110),
            const SizedBox(height: 14),
            Text(
              '¿A dónde quieres ir?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe tu punto de partida y tu destino para ver las rutas disponibles.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRoutesFound extends StatelessWidget {
  const _NoRoutesFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(AppAssets.mascot, width: 110),
            const SizedBox(height: 14),
            Text(
              'No encontramos una ruta registrada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Prueba con otra zona, cambia el tipo de transporte o registra una ruta nueva.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
