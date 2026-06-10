# Design — Ruta Fácil El Alto: Estabilización y Separación de Roles

> **Para agentes de código (Claude Code, Codex, etc.):**
> Este documento describe el estado ACTUAL del proyecto, lo que ya está implementado y NO se debe tocar,
> y los 3 cambios pendientes que deben ejecutarse. Lee la sección "Estado actual" antes de cualquier modificación.

---

## 1. Estado actual del proyecto (ya implementado — NO MODIFICAR)

### 1.1 Arquitectura general

```
lib/
├── main.dart                          → Carga AppSettings y arranca RutaFacilApp
├── app/
│   ├── ruta_facil_app.dart            → MaterialApp + AppSettingsScope (InheritedNotifier)
│   ├── app_settings.dart              → ChangeNotifier con tema, color, idioma, isCollectorMode
│   ├── app_theme.dart                 → ThemeData light/dark con colores por tipo de transporte
│   └── app_assets.dart                → Rutas de assets (logo, mascot, icon)
├── core/
│   ├── constants/app_constants.dart   → defaultAverageSpeedKmh = 18.0
│   └── utils/geo_utils.dart           → distanceInMeters, polylineDistanceInMeters
└── features/
    ├── home/presentation/home_page.dart         → Pantalla principal, bifurca por isCollectorMode
    ├── settings/presentation/settings_page.dart → Toggle isCollectorMode + tema + color + idioma
    ├── routes/
    │   ├── data/
    │   │   ├── local_route_repository.dart      → SQLite, seeding desde assets JSON
    │   │   ├── mock_route_repository.dart        → 5 rutas demo en memoria
    │   │   ├── route_repository_provider.dart    → Retorna LocalRouteRepository.instance
    │   │   ├── route_export_service.dart         → Exporta ruta a JSON y comparte
    │   │   └── route_json_codec.dart             → Encode/decode TransitRoute ↔ JSON
    │   ├── domain/
    │   │   ├── models/transit_route.dart         → TransitRoute, FareRule, RouteScheduleRule, TransportType
    │   │   ├── models/bus_position.dart          → BusPosition
    │   │   ├── models/route_report.dart          → RouteReport, ReportType
    │   │   ├── repositories/route_repository.dart → Interfaz RouteRepository
    │   │   └── services/                         → EtaService, RouteAvailabilityService, DeviationDetector, RoadRouteService
    │   └── presentation/
    │       ├── route_recording_controller.dart   → ChangeNotifier GPS (BUG ACTIVO aquí)
    │       ├── add_route_page.dart               → Formulario completo de grabación
    │       ├── map_page.dart                     → Mapa con filtros, polyline, buses simulados
    │       ├── route_detail_page.dart            → Detalle + acciones (BUG UI aquí)
    │       ├── routes_page.dart                  → Lista colector (getSavedRoutes)
    │       ├── favorites_page.dart               → Lista pasajero (getSavedRoutes)
    │       ├── search_destination_page.dart      → Búsqueda con autocomplete
    │       ├── available_now_page.dart           → Líneas activas según scheduleRules
    │       └── widgets/route_card.dart           → Card reutilizable de ruta
    └── share_location/presentation/             → Vacío (no implementado aún)
```

### 1.2 AppSettings — estado real

```dart
// lib/app/app_settings.dart
class AppSettings extends ChangeNotifier {
  // CLAVES EN SharedPreferences:
  static const _themeModeKey    = 'theme_mode';      // 'light' | 'dark'
  static const _accentColorKey  = 'accent_color';    // int 0-2
  static const _languageKey     = 'app_language';    // 'spanish' | 'aymara' | 'english'
  static const _collectorModeKey = 'collector_mode'; // bool — DEFAULT FALSE

  // GETTERS DISPONIBLES:
  bool get isCollectorMode => _isCollectorMode;  // ← YA EXISTE
  ThemeMode get themeMode  => _themeMode;
  Color get accentColor    => accentColors[_accentColorIndex];
  AppLanguage get language => _language;

  // MÉTODOS DISPONIBLES:
  Future<void> setCollectorMode(bool value);  // ← YA EXISTE
  Future<void> setThemeMode(ThemeMode mode);
  Future<void> setAccentColor(int index);
  Future<void> setLanguage(AppLanguage language);
}
```

⚠️ **Default de `isCollectorMode` es `false`** (modo pasajero). Cambiar a `true` desde Ajustes activa el modo colector.

### 1.3 UI condicional ya implementada en HomePage

| Widget | Condición | Estado |
|---|---|---|
| Saludo "Buenos días, colector" | `isCollectorMode == true` | ✅ |
| Subtítulo "Registra rutas reales..." | `isCollectorMode == true` | ✅ |
| Saludo "Buenos días" genérico | `isCollectorMode == false` | ✅ |
| Subtítulo "¿A dónde quieres ir hoy?" | `isCollectorMode == false` | ✅ |
| Card principal "Grabar ruta" (`_HeroActionCard`) | `isCollectorMode == true` | ✅ |
| Card grilla "Grabadas" → `RoutesPage` | `isCollectorMode == true` | ✅ |
| Card grilla "Rutas favoritas" → `FavoritesPage` | `isCollectorMode == false` | ✅ |
| Card "Disponibles ahora" (`_AvailableNowCard`) | `isCollectorMode == false` | ✅ |
| Barra de búsqueda → `SearchDestinationPage` | Siempre | ✅ |
| Card grilla "Mapa" → `MapPage` | Siempre | ✅ |
| Toggle en Ajustes | `SettingsPage` | ✅ |

### 1.4 Seeding de base de datos — estado real

El seeding **NO usa `MockRouteRepository`**. Usa assets JSON reales:

```dart
// lib/features/routes/data/local_route_repository.dart
static const _bundledRouteSeeds = [
  _BundledRouteSeed(
    routeId: 'manual-1779730822843',
    metadataKey: 'seeded_route_manual_1779730822843',
    assetPath: 'assets/routes/ruta_facil_no_tiene_manual-1779730822843.json',
    saveRoute: true,
  ),
  _BundledRouteSeed(
    routeId: 'manual-1779759085763',
    metadataKey: 'seeded_route_manual_1779759085763',
    assetPath: 'assets/routes/ruta_facil_204_manual-1779759085763.json',
    saveRoute: true,
  ),
];
```

El método `_seedBundledRoutesIfNeeded(db)` ya está implementado y es llamado en `getRoutes()` y `getSavedRoutes()`. **No modificar este sistema.**

### 1.5 RouteRecordingController — estado real (con bug activo)

```dart
// lib/features/routes/presentation/route_recording_controller.dart
Future<RouteRecordingStartResult> start() async {
  // ... permisos OK ...

  _isRecording = true;
  _startedAt = DateTime.now();
  _recordedPoints.clear();
  notifyListeners();

  // ❌ BUG AQUÍ: getCurrentPosition devuelve caché obsoleta del SO
  try {
    final initial = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _addPosition(initial);  // ← puede insertar (18.73, -70.16) República Dominicana
  } catch (_) {}

  // ✅ Correcto: el stream sí entrega posición real
  _positionSubscription = Geolocator.getPositionStream(
    locationSettings: _buildLocationSettings(),
  ).listen(_addPosition, onError: (_) => unawaited(stop()));

  return RouteRecordingStartResult.started;
}
```

---

## 2. Cambios pendientes (los únicos 3 que deben implementarse)

### CAMBIO 1 — Bug: Coordenada estale de República Dominicana

**Archivo:** `lib/features/routes/presentation/route_recording_controller.dart`

**Problema:** El bloque `try/catch` con `getCurrentPosition` inserta la última posición cacheada del SO como primer punto. En dispositivos con caché obsoleta, esto produce una polilínea trans-oceánica.

**Fix — eliminar exactamente estas líneas:**

```diff
     _isRecording = true;
     _startedAt = DateTime.now();
     _endedAt = null;
     _recordedPoints.clear();
     _currentSpeedKmh = 0;
     notifyListeners();

-    // Capture starting position immediately, before any movement triggers the stream.
-    try {
-      final initial = await Geolocator.getCurrentPosition(
-        locationSettings:
-            const LocationSettings(accuracy: LocationAccuracy.high),
-      );
-      _addPosition(initial);
-    } catch (_) {}
-
     _positionSubscription = Geolocator.getPositionStream(
```

**Resultado esperado:** `_recordedPoints` permanece vacío hasta que el stream en vivo entregue la primera posición real. El primer punto grabado tendrá latitud negativa (El Alto ≈ −16.5°S).

**Propiedad de corrección:**
```
PARA TODA sesión de grabación iniciada en El Alto:
  DESPUÉS de fix: recordedPoints.isEmpty hasta primer evento del stream
  recordedPoints.first.latitude < 0  (Hemisferio Sur)
```

**NO TOCAR:** El resto del método `start()`, `stop()`, `_addPosition()`, `_buildLocationSettings()`, ni ningún otro método del controller.

---

### CAMBIO 2 — Bug: Grabación en segundo plano se suspende en Android 14+

**Archivo:** `android/app/src/main/AndroidManifest.xml`

**Problema:** Los permisos `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_LOCATION` ya existen, pero falta la declaración `<service>` que Android 14+ requiere para iniciar el servicio en primer plano del plugin Geolocator.

**Fix — insertar dentro de `<application>`, justo después del cierre `</activity>` y antes del comentario `<!-- Don't delete the meta-data below -->`:**

```diff
         </activity>
+        <!-- Geolocator foreground service — requerido para tracking en segundo plano en Android 14+ -->
+        <service
+            android:name="com.baseflow.geolocator.GeolocatorLocationService"
+            android:enabled="true"
+            android:exported="false"
+            android:foregroundServiceType="location" />
         <!-- Don't delete the meta-data below.
```

**Resultado esperado:** En Android 14+, al enviar la app al fondo durante una grabación activa, el contador "Puntos" continúa incrementándose y la velocidad promedio se actualiza.

**NO TOCAR:** Los permisos existentes, la configuración de la `<activity>`, los `<meta-data>`, ni el bloque `<queries>`.

---

### CAMBIO 3 — UI: Ocultar "Borrar ruta" para pasajeros

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Problema:** El botón "Borrar ruta" actualmente se muestra a todos los usuarios. Un pasajero no debe poder borrar rutas del catálogo recolectado.

**Contexto del archivo:**
- `RouteDetailPage` es un `StatefulWidget` con `_RouteDetailPageState`
- No tiene acceso actual a `AppSettings` — hay que agregarlo
- `AppSettingsScope.of(context)` está disponible (se inyecta desde `RutaFacilApp`)

**Fix — en el método `build()` de `_RouteDetailPageState`:**

```diff
   @override
   Widget build(BuildContext context) {
     final route = widget.route;
     final eta = _etaService.estimateArrival(route);
     final activeInfo = _availabilityService.evaluate(route, DateTime.now());
+    final settings = AppSettingsScope.of(context);

     return Scaffold(
       appBar: AppBar(title: const Text('Detalle de ruta')),
```

```diff
           const SizedBox(height: 12),
-          OutlinedButton.icon(
-            onPressed: _confirmDeleteRoute,
-            icon: PhosphorIcon(PhosphorIcons.trash()),
-            label: const Text('Borrar ruta'),
-            style: OutlinedButton.styleFrom(
-              foregroundColor: Theme.of(context).colorScheme.error,
-            ),
-          ),
+          if (settings.isCollectorMode)
+            OutlinedButton.icon(
+              onPressed: _confirmDeleteRoute,
+              icon: PhosphorIcon(PhosphorIcons.trash()),
+              label: const Text('Borrar ruta'),
+              style: OutlinedButton.styleFrom(
+                foregroundColor: Theme.of(context).colorScheme.error,
+              ),
+            ),
           const SizedBox(height: 12),
```

**Import a agregar** al inicio del archivo (si no existe):
```dart
import '../../../app/ruta_facil_app.dart';
```

**Resultado esperado:**
- `isCollectorMode == false` (pasajero): "Borrar ruta" no aparece. Sí aparecen: "Ver mapa", bookmark, "Reportar", "Exportar".
- `isCollectorMode == true` (colector): Todo aparece como actualmente.

**NO TOCAR:** `_confirmDeleteRoute()`, `_toggleSaved()`, `_showReportDialog()`, `_exportRoute()`, ni ninguna otra acción o widget del detalle.

---

## 3. Wireframes UI — referencia visual

### 3.1 HomePage — modo pasajero (`isCollectorMode = false`)

```
┌─────────────────────────────────────────┐
│ AppBar: ⚙  Ruta Fácil                   │  ← ⚙ toca → SettingsPage
├─────────────────────────────────────────┤
│ Buenos días                             │  ← saludo genérico
│ ¿A dónde quieres ir hoy?               │
│                                         │
│ [🔍 Ej. 204, Rio Seco, UPEA...       >]│  ← toca → SearchDestinationPage
│                                         │
│ Mas opciones                            │
│ ┌──────────────┐  ┌──────────────┐     │
│ │ ⭐ Rutas      │  │ 🗺️ Mapa       │     │  ← FavoritesPage / MapPage
│ │ favoritas    │  │              │     │
│ │ Tus líneas   │  │ Ver recorri- │     │
│ │ guardadas    │  │ dos y buses  │     │
│ └──────────────┘  └──────────────┘     │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 🕐  Disponibles ahora               │ │  ← _AvailableNowCard → AvailableNowPage
│ │     N líneas circulando ahora    >  │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

AUSENTE en modo pasajero:
  ✗ Card "Grabar ruta" (HeroActionCard roja)
  ✗ Card grilla "Grabadas"
```

### 3.2 HomePage — modo colector (`isCollectorMode = true`)

```
┌─────────────────────────────────────────┐
│ AppBar: ⚙  Ruta Fácil                   │
├─────────────────────────────────────────┤
│ Buenos días, colector                   │  ← saludo personalizado
│ Registra rutas reales de El Alto.       │
│                                         │
│ [🔍 Ej. 204, Rio Seco, UPEA...       >]│
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 🔴  Grabar ruta                   > │ │  ← HeroActionCard → AddRoutePage
│ │     GPS, dia, hora, pasaje y ruta   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Mas opciones                            │
│ ┌──────────────┐  ┌──────────────┐     │
│ │ 🗺️ Mapa       │  │ 🔖 Grabadas   │     │  ← MapPage / RoutesPage
│ │ Ver recorri- │  │ Recorridos   │     │
│ │ dos y buses  │  │ en campo     │     │
│ └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────┘

AUSENTE en modo colector:
  ✗ Card "Rutas favoritas"
  ✗ Card "Disponibles ahora"
```

### 3.3 RouteDetailPage — acciones por modo

```
MODO PASAJERO (isCollectorMode = false):
┌─────────────────────────────────────────┐
│ [Ver mapa]          [🔖 bookmark toggle] │  ← FilledButton + IconButton
│ [Reportar cambio o problema           ] │  ← OutlinedButton
│ [Exportar o compartir ruta            ] │  ← OutlinedButton
│                                         │
│ ✗ "Borrar ruta" NO aparece             │  ← OCULTO
└─────────────────────────────────────────┘

MODO COLECTOR (isCollectorMode = true):
┌─────────────────────────────────────────┐
│ [Ver mapa]          [🔖 bookmark toggle] │
│ [Reportar cambio o problema           ] │
│ [Exportar o compartir ruta            ] │
│ [🗑️ Borrar ruta                        ] │  ← OutlinedButton rojo — VISIBLE
└─────────────────────────────────────────┘
```

### 3.4 SettingsPage — toggle de modo

```
┌─────────────────────────────────────────┐
│ AppBar: Ajustes                         │
├─────────────────────────────────────────┤
│ APARIENCIA                              │
│ Tema          Naranja  [Naranja][Oscuro]│
│ Color de acento   Ámbar  ● ● ●         │
│                                         │
│ IDIOMA                                  │
│ Idioma        Español  [dropdown]       │
│                                         │
│ AVANZADO                                │
│ 🔴 Modo colector              [toggle] │  ← settings.setCollectorMode(value)
│    Activa opciones para grabar          │
│    rutas en campo                       │
└─────────────────────────────────────────┘
```

---

## 4. Flujo de estado — AppSettings como fuente de verdad

```
main.dart
  └─ AppSettings.load()         → carga SharedPreferences
       └─ RutaFacilApp          → AppSettingsScope (InheritedNotifier)
            └─ AnimatedBuilder  → se reconstruye en cada notifyListeners()
                 └─ HomePage    → lee AppSettingsScope.of(context).isCollectorMode
                                  → bifurca UI según valor
                 └─ SettingsPage → llama settings.setCollectorMode(true/false)
                                   → notifyListeners() → AnimatedBuilder rebuild
                 └─ RouteDetailPage → [PENDIENTE] leer isCollectorMode
```

---

## 5. Tabla de widgets condicionales — resumen completo

| Widget | Archivo | Condición | Estado |
|---|---|---|---|
| Saludo + subtítulo colector | `home_page.dart` → `_HeroHeader` | `isCollector == true` | ✅ Implementado |
| Saludo + subtítulo pasajero | `home_page.dart` → `_HeroHeader` | `isCollector == false` | ✅ Implementado |
| `_HeroActionCard` "Grabar ruta" | `home_page.dart` | `isCollectorMode == true` | ✅ Implementado |
| Card "Grabadas" (grilla) | `home_page.dart` | `isCollectorMode == true` | ✅ Implementado |
| Card "Rutas favoritas" (grilla) | `home_page.dart` | `isCollectorMode == false` | ✅ Implementado |
| `_AvailableNowCard` | `home_page.dart` | `isCollectorMode == false` | ✅ Implementado |
| Toggle "Modo colector" | `settings_page.dart` | Siempre visible | ✅ Implementado |
| Botón "Borrar ruta" | `route_detail_page.dart` | `isCollectorMode == true` | ❌ **PENDIENTE** |

---

## 6. Correctness Properties

### P1 — Fix Bug GPS (Cambio 1)
```
PARA TODA sesión de grabación iniciada en El Alto (lat ≈ -16.5):
  recordedPoints.isEmpty  inmediatamente después de start() retornar
  Y recordedPoints.first.latitude < 0  después del primer evento del stream
```

### P2 — Fix Manifest Android (Cambio 2)
```
AndroidManifest.xml CONTIENE:
  <service android:name="com.baseflow.geolocator.GeolocatorLocationService"
           android:foregroundServiceType="location"
           android:exported="false" />
```

### P3 — UI Borrar Ruta (Cambio 3)
```
PARA TODO widget tree donde isCollectorMode == false:
  find('Borrar ruta').isEmpty == true

PARA TODO widget tree donde isCollectorMode == true:
  find('Borrar ruta').isNotEmpty == true
  find('Reportar cambio o problema').isNotEmpty == true
  find('Exportar o compartir ruta').isNotEmpty == true
```
