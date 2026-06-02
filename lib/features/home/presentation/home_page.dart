import 'package:flutter/material.dart';

import '../../../app/app_settings.dart';
import '../../../app/app_theme.dart';
import '../../../app/ruta_facil_app.dart';
import '../../routes/presentation/add_route_page.dart';
import '../../routes/presentation/map_page.dart';
import '../../routes/presentation/routes_page.dart';
import '../../routes/presentation/search_destination_page.dart';
import '../../settings/presentation/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _goSearch() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SearchDestinationPage()),
      );

  void _goSettings() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final int maxIndex = settings.isCollectorMode ? 2 : 1;
    final int safeIndex = _selectedIndex.clamp(0, maxIndex);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: [
          _HomeTab(
            settings: settings,
            onSearch: _goSearch,
            onOpenSettings: _goSettings,
          ),
          const MapPage(),
          if (settings.isCollectorMode)
            const RoutesPage()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          if (settings.isCollectorMode)
            const NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Grabadas',
            ),
        ],
      ),
    );
  }
}

// ── Tab de inicio ────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.settings,
    required this.onSearch,
    required this.onOpenSettings,
  });

  final AppSettings settings;
  final VoidCallback onSearch;
  final VoidCallback onOpenSettings;

  String _greeting() {
    final hour = DateTime.now().hour;
    final saludo =
        hour < 12 ? 'Buenos días' : (hour < 19 ? 'Buenas tardes' : 'Buenas noches');
    return settings.isCollectorMode ? '$saludo, colector' : saludo;
  }

  String _subtitle() =>
      settings.isCollectorMode ? 'Registra rutas reales' : '¿A dónde quieres ir?';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final onPrimary = colors.onPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header con color primario ────────────────────────────────────
        Container(
          color: colors.primary,
          padding: EdgeInsets.fromLTRB(20, topPadding + 12, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: onPrimary.withValues(alpha: 0.80),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: onPrimary),
                    tooltip: 'Ajustes',
                    onPressed: onOpenSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onSearch,
                child: AbsorbPointer(
                  child: SearchBar(
                    hintText: 'Ej. 204, Rio Seco, UPEA, Villa Adela',
                    leading: const Icon(Icons.search),
                    trailing: const [Icon(Icons.arrow_forward_ios, size: 14)],
                    elevation: const WidgetStatePropertyAll(0),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Cuerpo ──────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (settings.isCollectorMode) ...[
                _HeroActionCard(
                  option: _HomeOption(
                    title: 'Grabar ruta',
                    subtitle: 'GPS, dia, hora, pasaje y recorrido real',
                    icon: Icons.fiber_manual_record,
                    color: AppTheme.modified,
                    onTap: () {},
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddRoutePage()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Widgets internos ─────────────────────────────────────────────────────────

class _HeroActionCard extends StatelessWidget {
  const _HeroActionCard({required this.option, required this.onTap});

  final _HomeOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
