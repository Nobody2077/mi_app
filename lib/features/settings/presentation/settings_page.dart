import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../app/app_settings.dart';
import '../../../app/ruta_facil_app.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return ListView(
            children: [
              _SectionHeader('Apariencia'),
              _ThemeTile(settings: settings),
              _AccentColorTile(settings: settings),
              _SectionHeader('Idioma'),
              _LanguageTile(settings: settings),
              _SectionHeader('Avanzado'),
              SwitchListTile(
                value: settings.isCollectorMode,
                title: const Text('Modo colector'),
                subtitle: const Text('Activa opciones para grabar rutas en campo'),
                secondary: PhosphorIcon(PhosphorIcons.record(PhosphorIconsStyle.fill)),
                onChanged: settings.setCollectorMode,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Tema'),
      subtitle: Text(
        settings.themeMode == ThemeMode.dark ? 'Oscuro' : 'Claro',
      ),
      leading: PhosphorIcon(
        settings.isDarkMode ? PhosphorIcons.moon() : PhosphorIcons.sun(),
      ),
      trailing: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            icon: PhosphorIcon(PhosphorIcons.sun()),
            label: const Text('Claro'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: PhosphorIcon(PhosphorIcons.moon()),
            label: const Text('Oscuro'),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (s) => settings.setThemeMode(s.first),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _AccentColorTile extends StatelessWidget {
  const _AccentColorTile({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Color de acento'),
      subtitle: Text(AppSettings.accentColorLabels[settings.accentColorIndex]),
      leading: PhosphorIcon(PhosphorIcons.palette()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(AppSettings.accentColors.length, (i) {
          final color = AppSettings.accentColors[i];
          final selected = i == settings.accentColorIndex;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => settings.setAccentColor(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                      : null,
                ),
                child: selected
                    ? PhosphorIcon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 16, color: _contrastFor(color))
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _contrastFor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.settings});
  final AppSettings settings;

  static const _labels = {
    AppLanguage.spanish: 'Español',
    AppLanguage.aymara: 'Aymara',
    AppLanguage.english: 'English',
  };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Idioma'),
      subtitle: Text(_labels[settings.language]!),
      leading: PhosphorIcon(PhosphorIcons.globe()),
      trailing: DropdownButton<AppLanguage>(
        value: settings.language,
        underline: const SizedBox.shrink(),
        items: AppLanguage.values
            .map(
              (l) => DropdownMenuItem(
                value: l,
                child: Text(_labels[l]!),
              ),
            )
            .toList(),
        onChanged: (l) {
          if (l != null) settings.setLanguage(l);
        },
      ),
    );
  }
}
