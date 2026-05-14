import 'package:flutter/material.dart';

import '../../../app/app_assets.dart';
import '../../../app/app_theme.dart';
import '../../../app/ruta_facil_app.dart';
import '../../routes/presentation/add_route_page.dart';
import '../../routes/presentation/map_page.dart';
import '../../routes/presentation/routes_page.dart';
import '../../routes/presentation/search_destination_page.dart';
import '../../share_location/presentation/share_location_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      _HomeOption(
        title: 'Buscar',
        subtitle: 'Origen, destino, linea o sindicato',
        icon: Icons.search,
        color: AppTheme.minibus,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchDestinationPage()),
        ),
      ),
      _HomeOption(
        title: 'Grabar ruta',
        subtitle: 'GPS, dia, hora, pasaje y recorrido real',
        icon: Icons.fiber_manual_record,
        color: AppTheme.modified,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddRoutePage())),
      ),
      _HomeOption(
        title: 'Mapa',
        subtitle: 'Ver recorridos y buses simulados',
        icon: Icons.map_outlined,
        color: AppTheme.trufi,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MapPage())),
      ),
      _HomeOption(
        title: 'Grabadas',
        subtitle: 'Recorridos recolectados en campo',
        icon: Icons.bookmark_outline,
        color: AppTheme.micro,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RoutesPage())),
      ),
      _HomeOption(
        title: 'Reportar',
        subtitle: 'Bloqueo, feria, trameaje o ruta cambiada',
        icon: Icons.my_location,
        color: const Color(0xFF6D5BD0),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ShareLocationPage())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Facil El Alto'),
        actions: [
          IconButton(
            tooltip: 'Tema',
            onPressed: () => _showThemeSheet(context),
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroHeader(
            onRecord: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddRoutePage())),
            onSearch: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchDestinationPage()),
            ),
          ),
          const SizedBox(height: 16),
          _QuickSearchPanel(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchDestinationPage()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Acciones principales',
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

  void _showThemeSheet(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Naranja'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Oscuro'),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (selection) {
                  settings.setThemeMode(selection.first);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onRecord, required this.onSearch});

  final VoidCallback onRecord;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    AppAssets.logo,
                    height: 70,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recolector de rutas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Registra recorridos reales de El Alto con GPS, pasaje, dia y hora.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onRecord,
                        icon: const Icon(Icons.fiber_manual_record),
                        label: const Text('Grabar ruta'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onSearch,
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(AppAssets.mascot, width: 82),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSearchPanel extends StatelessWidget {
  const _QuickSearchPanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.search, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buscar una ruta o destino',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text('Ej. 204, Rio Seco, UPEA, Villa Adela'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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
