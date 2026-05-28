# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter analyze          # Static analysis (flutter_lints)
flutter test             # Run all tests
flutter test test/path_to_test.dart  # Run a single test file
flutter build apk        # Build Android APK
dart run flutter_native_splash:create    # Regenerate splash screen
dart run flutter_launcher_icons          # Regenerate launcher icons
```

## Architecture

Feature-based Clean Architecture. Each feature under `lib/features/` is divided into three layers:

- **`domain/`** — pure Dart: models, abstract `RouteRepository` interface, and service classes (`EtaService`, `DeviationDetector`, `RoadRouteService`, `RouteAvailabilityService`).
- **`data/`** — implementations: `LocalRouteRepository` (SQLite singleton), `MockRouteRepository` (tests), `RouteExportService` (JSON sharing).
- **`presentation/`** — `StatefulWidget` pages + `FutureBuilder` for async loads. No BLoC/Provider/Riverpod — plain `setState`.

**App-level settings** (`lib/app/`): `AppSettings` extends `ChangeNotifier` and is loaded before `runApp`. It is distributed down the tree via `AppSettingsScope` (`InheritedNotifier<AppSettings>`). Access with `AppSettingsScope.of(context)`.

**Repository access**: `LocalRouteRepository.instance` is a private-constructor singleton. The abstract `RouteRepository` interface lives in `domain/repositories/` — use it for type annotations so tests can swap in `MockRouteRepository`.

## Key domain details

- `TransitRoute.path` is `List<LatLng>` — ordered GPS control points recorded in the field. Sparse paths can be snapped to real roads via OSRM (`RoadRouteService`) when online.
- `RouteScheduleRule` and `FareRule` both expose `appliesAt(DateTime)` for time/weekday matching.
- `BusPosition` objects returned by `getBusPositions` are **simulated** (placed at first and midpoint of the path) — there is no real-time bus feed.
- Deviation threshold is 250 m (`AppConstants.deviationThresholdMeters`); default ETA speed is 18 km/h (`AppConstants.defaultAverageSpeedKmh`).
- Demo credentials (`AppConstants.demoUser` / `demoPassword`) are `admin`/`1234` — the app currently skips the login screen and goes straight to `HomePage`.

## Database

SQLite via `sqflite`, file `ruta_facil_el_alto.db`, current schema version **2**. Tables: `routes`, `route_stops`, `route_points`, `fare_rules`, `schedule_rules`, `saved_routes`, `route_reports`, `metadata`. All multi-table writes use transactions. Schema migrations live in `_upgradeSchema` inside `LocalRouteRepository`.

## Kiro Rules

* Leer primero la carpeta `.kiro/`
* Usar `.kiro/` como fuente principal de verdad
* Priorizar specs y tasks existentes antes de proponer cambios
* No contradecir requerimientos definidos en Kiro
* Preguntar antes de modificar arquitectura o flujos definidos en `.kiro/`

## Working Rules

* Responder en español
* No modificar archivos sin permiso explícito
* Primero analizar, luego proponer y finalmente implementar
* No instalar dependencias sin confirmación
* No hacer commits automáticamente
