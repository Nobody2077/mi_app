import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../app/ruta_facil_app.dart';
import '../../routes/presentation/add_route_page.dart';
import '../../routes/presentation/favorites_page.dart';
import '../../routes/presentation/map_page.dart';
import '../../routes/presentation/passenger_map_page.dart';
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
      icon: PhosphorIcons.record(PhosphorIconsStyle.fill),
      color: AppTheme.modified,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddRoutePage()),
      ),
    );

    final options = [
      if (!settings.isCollectorMode)
        _HomeOption(
          title: 'Rutas favoritas',
          subtitle: 'Tus líneas guardadas, listas en un tap',
          icon: PhosphorIcons.star(),
          color: AppTheme.micro,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ),
        ),
      _HomeOption(
        title: 'Mapa',
        subtitle: settings.isCollectorMode
            ? 'Ver recorridos y buses en el mapa'
            : 'Encuentra buses y rutas cerca de ti',
        icon: PhosphorIcons.mapTrifold(),
        color: AppTheme.trufi,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => settings.isCollectorMode
                ? const MapPage()
                : const PassengerMapPage(),
          ),
        ),
      ),
      if (settings.isCollectorMode)
        _HomeOption(
          title: 'Grabadas',
          subtitle: 'Recorridos recolectados en campo',
          icon: PhosphorIcons.bookmarkSimple(),
          color: AppTheme.micro,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RoutesPage()),
          ),
        ),
    ];

    final appBarFg = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text(
          'Ruta Fácil',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: appBarFg,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: PhosphorIcon(PhosphorIcons.gearSix(), size: 22, color: appBarFg),
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
                hintText: 'Buscar destino o línea',
                leading: PhosphorIcon(PhosphorIcons.magnifyingGlass()),
                trailing: [PhosphorIcon(PhosphorIcons.caretRight(), size: 14)],
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
        Text(_greeting(), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          _subtitle(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
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
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PhosphorIcon(PhosphorIcons.arrowRight(), color: option.color, size: 16),
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
                style: Theme.of(context).textTheme.bodyMedium,
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
