# Plan de implementación — Ruta Fácil Estabilización

> **Para agentes de código:** Solo hay 3 tareas pendientes. Todo lo demás ya está implementado.
> Lee `design.md` antes de empezar. Presta especial atención a la sección "NO TOCAR" de cada tarea.

---

## ✅ Ya completado (no repetir)

- [x] Extracción de `RouteRecordingController` a archivo separado (`ChangeNotifier`, GPS stream, permisos)
- [x] `AppSettings.isCollectorMode` con `SharedPreferences` (clave `'collector_mode'`, default `false`)
- [x] `AppSettings.setCollectorMode(bool)` con `notifyListeners()`
- [x] Toggle "Modo colector" en `SettingsPage`
- [x] `HomePage` bifurcada por `isCollectorMode` (Grabar ruta, Grabadas, Rutas favoritas)
- [x] `_HeroHeader` con saludo personalizado por modo
- [x] Seeding de rutas desde assets JSON (`_bundledRouteSeeds`) en `LocalRouteRepository`
- [x] `FavoritesPage`, `RoutesPage`, `SearchDestinationPage` — completos
- [x] Ícono de Ajustes (⚙) movido a `actions` del AppBar (esquina superior derecha) en `home_page.dart` (2026-06-10)
- [x] Card "Disponibles ahora" (`_AvailableNowCard` / `AvailableNowPage`) eliminada por no funcional (2026-06-10)
- [x] `MapPage` con filtros, polyline, snap to roads, buses simulados — completo
- [x] Permisos de Android en `AndroidManifest.xml`: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- [x] `ForegroundNotificationConfig` en `AndroidSettings` dentro del controller
- [x] Declaración `<service android:name="com.baseflow.geolocator.GeolocatorLocationService">` en `AndroidManifest.xml`

---

## Tareas pendientes

### ⏸️ Tarea 1 — EN PAUSA: Corregir bug de coordenada estale (República Dominicana)

> **Estado: pausada (2026-06-10).** Verificación técnica contra el código fuente real de
> `geolocator_android-5.0.2` (la versión usada por `geolocator: ^14.0.2` en este proyecto)
> muestra que `Geolocator.getCurrentPosition()` **NO** llama a `getLastLocation()` (la API
> de caché). Llama a `requestLocationUpdates()` y resuelve con el primer `onLocationResult`,
> es decir, el **mismo mecanismo** que usa `getPositionStream()`. La premisa del bug
> ("getCurrentPosition devuelve caché obsoleta del SO") no se sostiene para esta versión
> del plugin.
>
> Además, el usuario confirma que **actualmente funciona bien** — no se ha observado el
> salto a República Dominicana / Atlántico en la práctica.
>
> Eliminar el bloque `try/catch` cambiaría el comportamiento (el primer punto tardaría
> hasta 5s/12m en aparecer vía stream, y el contador "Puntos" empezaría en 0 en vez de 1)
> **sin resolver un defecto demostrado**. Si el escenario descrito fuera real, afectaría
> también al primer evento del stream (que también queda como `recordedPoints[0]` por la
> condición `_recordedPoints.isEmpty`), por lo que el fix propuesto tampoco lo cubriría.
>
> **No aplicar esta tarea** hasta tener un log/reporte real de coordenadas erróneas que
> la respalde. Mientras tanto, se prioriza otro trabajo (UI).

**Archivo:** `lib/features/routes/presentation/route_recording_controller.dart`

**Descripción:** Eliminar el bloque `try/catch` con `Geolocator.getCurrentPosition` del método `start()`. Este bloque inserta la posición cacheada del SO como primer punto, lo que en dispositivos con caché obsoleta produce una polilínea de ~7,000 km cruzando el Atlántico.

**Cambio exacto — eliminar el bloque marcado:**

```dart
// ANTES (líneas a eliminar — buscar este bloque exacto):
    // Capture starting position immediately, before any movement triggers the stream.
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _addPosition(initial);
    } catch (_) {}

// DESPUÉS (estas líneas simplemente desaparecen):
    // <nada — el bloque se elimina completo>
```

**El resultado del método `start()` después del fix debe quedar así (fragmento):**

```dart
    _isRecording = true;
    _startedAt = DateTime.now();
    _endedAt = null;
    _recordedPoints.clear();
    _currentSpeedKmh = 0;
    notifyListeners();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(_addPosition, onError: (_) => unawaited(stop()));

    return RouteRecordingStartResult.started;
```

**NO TOCAR:**
- `_buildLocationSettings()` — no modificar
- `_addPosition()` — no modificar
- `stop()` — no modificar
- Los checks de permisos al inicio de `start()` — no modificar
- El `notifyListeners()` inicial — no modificar

**Verificación:**
- El archivo compila sin errores (`flutter analyze`)
- `_recordedPoints` está vacío inmediatamente después de que `start()` retorna `started`
- El primer punto en `_recordedPoints` llega desde el stream (latitud negativa para El Alto)

---

### ~~Tarea 2~~ ✅ — Registrar el servicio Geolocator en AndroidManifest para Android 14+

> **YA IMPLEMENTADO** — el `<service>` existe en `android/app/src/main/AndroidManifest.xml`. No hacer nada.

**Archivo:** `android/app/src/main/AndroidManifest.xml`

**Descripción:** ~~Agregar la declaración `<service>` para `GeolocatorLocationService`~~ Ya declarado correctamente con `android:foregroundServiceType="location"` y `android:exported="false"`.

**Ubicación exacta:** Después del cierre `</activity>` y antes del comentario `<!-- Don't delete the meta-data below -->`.

**XML a insertar:**

```xml
        <!-- Geolocator foreground service — requerido para tracking en segundo plano en Android 14+ -->
        <service
            android:name="com.baseflow.geolocator.GeolocatorLocationService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="location" />
```

**Estructura resultante del bloque `<application>` (fragmento):**

```xml
    <application
        android:label="mi_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            ...>
            ...
        </activity>
        <!-- Geolocator foreground service — requerido para tracking en segundo plano en Android 14+ -->
        <service
            android:name="com.baseflow.geolocator.GeolocatorLocationService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="location" />
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
```

**NO TOCAR:**
- Los `<uses-permission>` existentes — no modificar
- La `<activity>` de `MainActivity` — no modificar
- Los `<meta-data>` existentes — no modificar
- El bloque `<queries>` al final — no modificar

**Verificación:**
- El XML es válido (sin errores de sintaxis)
- `<service android:name="com.baseflow.geolocator.GeolocatorLocationService">` existe dentro de `<application>`
- `android:foregroundServiceType="location"` está presente
- `android:exported="false"` está presente

---

### ✅ Tarea 3 — COMPLETADA: Ocultar "Borrar ruta" y "Exportar o compartir ruta" para usuarios en modo pasajero

> **Estado: implementada (2026-06-10).** Alcance ampliado respecto al original: además de
> "Borrar ruta", también se oculta "Exportar o compartir ruta" cuando `isCollectorMode == false`
> (decisión del usuario). "Reportar cambio o problema", "Ver mapa" y el bookmark siguen
> visibles para todos.

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Descripción:** Los botones "Borrar ruta" y "Exportar o compartir ruta" se mostraban a todos los usuarios. Ahora se ocultan cuando `isCollectorMode == false`. Los pasajeros no deben poder modificar el catálogo de rutas ni exportar/compartir archivos de ruta.

**Paso 3a — Agregar import** (verificar si ya existe antes de agregar):

```dart
import '../../../app/ruta_facil_app.dart';
```

**Paso 3b — En el método `build()` de `_RouteDetailPageState`, agregar lectura de settings:**

Buscar este bloque al inicio de `build()`:

```dart
  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final eta = _etaService.estimateArrival(route);
    final activeInfo = _availabilityService.evaluate(route, DateTime.now());
```

Agregar la línea de `settings` justo después:

```dart
  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final eta = _etaService.estimateArrival(route);
    final activeInfo = _availabilityService.evaluate(route, DateTime.now());
    final settings = AppSettingsScope.of(context);  // ← AGREGAR
```

**Paso 3c — Envolver "Exportar o compartir ruta" y "Borrar ruta" en un solo bloque condicional:**

Buscar este fragmento exacto en el `ListView` del `build()`:

```dart
          OutlinedButton.icon(
            onPressed: _showReportDialog,
            icon: PhosphorIcon(PhosphorIcons.warning()),
            label: const Text('Reportar cambio o problema'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportRoute,
            icon: PhosphorIcon(PhosphorIcons.shareNetwork()),
            label: const Text('Exportar o compartir ruta'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _confirmDeleteRoute,
            icon: PhosphorIcon(PhosphorIcons.trash()),
            label: const Text('Borrar ruta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
```

Reemplazar por:

```dart
          OutlinedButton.icon(
            onPressed: _showReportDialog,
            icon: PhosphorIcon(PhosphorIcons.warning()),
            label: const Text('Reportar cambio o problema'),
          ),
          if (settings.isCollectorMode) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _exportRoute,
              icon: PhosphorIcon(PhosphorIcons.shareNetwork()),
              label: const Text('Exportar o compartir ruta'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmDeleteRoute,
              icon: PhosphorIcon(PhosphorIcons.trash()),
              label: const Text('Borrar ruta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
```

**NO TOCAR:**
- `_confirmDeleteRoute()`, `_toggleSaved()`, `_showReportDialog()`, `_exportRoute()` — no modificar
- El botón "Reportar cambio o problema" — visible para todos, no tocar
- El botón "Ver mapa" — visible para todos, no tocar
- El bookmark `IconButton.filledTonal` — visible para todos, no tocar
- `_loadState()`, `initState()`, ni ninguna otra lógica de estado

**Verificación:**
- Con `isCollectorMode = false`: "Borrar ruta" y "Exportar o compartir ruta" NO aparecen en el widget tree
- Con `isCollectorMode = true`: ambos botones SÍ aparecen (comportamiento actual)
- "Reportar cambio o problema", "Ver mapa" y el bookmark siguen visibles en ambos modos
- `flutter analyze` sin errores ✅ (verificado)

---

## Orden de ejecución recomendado

```
Tarea 1 (controller, EN PAUSA)  →  Tarea 3 (UI detail, COMPLETADA)
```

La Tarea 2 ya está completa. La Tarea 3 ya está completa. Solo queda la Tarea 1, en pausa.

---

## Checkpoint final

- [ ] `flutter analyze` — cero errores, cero warnings nuevos (✅ verificado en el subset tocado por la Tarea 3)
- [ ] `flutter build apk --debug` — compila sin errores
- [ ] En `route_recording_controller.dart`: no existe ninguna llamada a `Geolocator.getCurrentPosition` — **N/A, Tarea 1 en pausa**
- [x] En `AndroidManifest.xml`: existe `<service android:name="com.baseflow.geolocator.GeolocatorLocationService" android:foregroundServiceType="location" />`
- [x] En `route_detail_page.dart`: "Borrar ruta" y "Exportar o compartir ruta" están envueltos en `if (settings.isCollectorMode)`
- [x] En `route_detail_page.dart`: el archivo importa `ruta_facil_app.dart`
