import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../app/ruta_facil_app.dart';
import '../../routes/presentation/add_route_page.dart';
import '../../routes/presentation/map_page.dart';
import '../../routes/presentation/routes_page.dart';
import '../../routes/presentation/search_destination_page.dart';
import '../../settings/presentation/settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    void goSearch() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchDestinationPage()),
        );

    final heroOption = _HomeOption(
      title: 'Grabar ruta',
      subtitle: 'GPS, dia, hora, pasaje y recorrido real',
      icon: Icons.fiber_manual_record,
      color: AppTheme.modified,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddRoutePage()),
      ),
    );

    final options = [
      _HomeOption(
        title: 'Buscar',
        subtitle: 'Origen, destino, linea o sindicato',
        icon: Icons.search,
        color: AppTheme.minibus,
        onTap: goSearch,
      ),
      _HomeOption(
        title: 'Mapa',
        subtitle: 'Ver recorridos y buses simulados',
        icon: Icons.map_outlined,
        color: AppTheme.trufi,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MapPage()),
        ),
      ),
      if (settings.isCollectorMode)
        _HomeOption(
          title: 'Grabadas',
          subtitle: 'Recorridos recolectados en campo',
          icon: Icons.bookmark_outline,
          color: AppTheme.micro,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutesPage()),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Facil El Alto'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroHeader(isCollector: settings.isCollectorMode),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: goSearch,
            child: AbsorbPointer(
              child: SearchBar(
                hintText: 'Ej. 204, Rio Seco, UPEA, Villa Adela',
                leading: const Icon(Icons.search),
                trailing: const [Icon(Icons.arrow_forward_ios, size: 14)],
              ),
            ),
          ),
          if (settings.isCollectorMode) ...[
            const SizedBox(height: 16),
            _HeroActionCard(option: heroOption),
          ],
          const SizedBox(height: 16),
          Text(
            'Mas opciones',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          GridView.builder(
            itemCount: options.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) => _HomeCard(option: options[index]),
          ),
        ],
      ),
    );
  }

}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isCollector});

  final bool isCollector;

  String _greeting() {
    final hour = DateTime.now().hour;
    final saludo = hour < 12 ? 'Buenos dias' : (hour < 19 ? 'Buenas tardes' : 'Buenas noches');
    return isCollector ? '$saludo, colector' : saludo;
  }

  String _subtitle() {
    return isCollector
        ? 'Registra rutas reales de El Alto con GPS.'
        : '¿A dónde quieres ir hoy?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_greeting(), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(_subtitle(), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard({required this.option});

  final _HomeOption option;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: option.onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                option.color.withValues(alpha: 0.18),
                option.color.withValues(alpha: 0.04),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(option.icon, color: option.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: option.color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.option});

  final _HomeOption option;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: option.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.color),
              ),
              const Spacer(),
              Text(
                option.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                option.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeOption {
  const _HomeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
