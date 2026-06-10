# Plan de implementación — Ruta Fácil Estabilización

> **Para agentes de código:** Solo hay 3 tareas pendientes. Todo lo demás ya está implementado.
> Lee `design.md` antes de empezar. Presta especial atención a la sección "NO TOCAR" de cada tarea.

---

## ✅ Ya completado (no repetir)

- [x] Extracción de `RouteRecordingController` a archivo separado (`ChangeNotifier`, GPS stream, permisos)
- [x] `AppSettings.isCollectorMode` con `SharedPreferences` (clave `'collector_mode'`, default `false`)
- [x] `AppSettings.setCollectorMode(bool)` con `notifyListeners()`
- [x] Toggle "Modo colector" en `SettingsPage`
- [x] `HomePage` bifurcada por `isCollectorMode` (Grabar ruta, Grabadas, Rutas favoritas, Disponibles ahora)
- [x] `_HeroHeader` con saludo personalizado por modo
- [x] Seeding de rutas desde assets JSON (`_bundledRouteSeeds`) en `LocalRouteRepository`
- [x] `FavoritesPage`, `RoutesPage`, `SearchDestinationPage`, `AvailableNowPage` — completos
- [x] `MapPage` con filtros, polyline, snap to roads, buses simulados — completo
- [x] Permisos de Android en `AndroidManifest.xml`: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- [x] `ForegroundNotificationConfig` en `AndroidSettings` dentro del controller

---

## Tareas pendientes

### Tarea 1 — Corregir bug de coordenada estale (República Dominicana)

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

### Tarea 2 — Registrar el servicio Geolocator en AndroidManifest para Android 14+

**Archivo:** `android/app/src/main/AndroidManifest.xml`

**Descripción:** Agregar la declaración `<service>` para `GeolocatorLocationService` dentro del elemento `<application>`. Sin esto, Android 14+ no permite iniciar el servicio en primer plano y la grabación se suspende al enviar la app al fondo.

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

### Tarea 3 — Ocultar botón "Borrar ruta" para usuarios en modo pasajero

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Descripción:** El botón "Borrar ruta" actualmente se muestra a todos los usuarios. Debe ocultarse cuando `isCollectorMode == false`. Los pasajeros no deben poder modificar el catálogo de rutas.

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

**Paso 3c — Envolver el botón "Borrar ruta" con la condición:**

Buscar este widget exacto en el `ListView` del `build()`:

```dart
          OutlinedButton.icon(
            onPressed: _confirmDeleteRoute,
            icon: PhosphorIcon(PhosphorIcons.trash()),
            label: const Text('Borrar ruta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
```

Reemplazar por:

```dart
          if (settings.isCollectorMode)
            OutlinedButton.icon(
              onPressed: _confirmDeleteRoute,
              icon: PhosphorIcon(PhosphorIcons.trash()),
              label: const Text('Borrar ruta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
```

**NO TOCAR:**
- `_confirmDeleteRoute()` — el método existe y funciona, no modificar
- `_toggleSaved()`, `_showReportDialog()`, `_exportRoute()` — no modificar
- El botón "Reportar cambio o problema" — visible para todos, no tocar
- El botón "Exportar o compartir ruta" — visible para todos, no tocar
- El botón "Ver mapa" — visible para todos, no tocar
- El bookmark `IconButton.filledTonal` — visible para todos, no tocar
- `_loadState()`, `initState()`, ni ninguna otra lógica de estado

**Verificación:**
- Con `isCollectorMode = false`: el botón "Borrar ruta" NO aparece en el widget tree
- Con `isCollectorMode = true`: el botón "Borrar ruta" SÍ aparece (comportamiento actual)
- Los demás botones (Ver mapa, bookmark, Reportar, Exportar) siguen visibles en ambos modos
- `flutter analyze` sin errores

---

## Orden de ejecución recomendado

```
Tarea 1 (controller)  →  Tarea 2 (manifest)  →  Tarea 3 (UI detail)
```

Las tres tareas son independientes entre sí y pueden hacerse en cualquier orden. El orden sugerido prioriza los bugs críticos de GPS primero.

---

## Checkpoint final

Después de completar las 3 tareas:

- [ ] `flutter analyze` — cero errores, cero warnings nuevos
- [ ] `flutter build apk --debug` — compila sin errores
- [ ] En `route_recording_controller.dart`: no existe ninguna llamada a `Geolocator.getCurrentPosition`
- [ ] En `AndroidManifest.xml`: existe `<service android:name="com.baseflow.geolocator.GeolocatorLocationService" android:foregroundServiceType="location" />`
- [ ] En `route_detail_page.dart`: el botón "Borrar ruta" está envuelto en `if (settings.isCollectorMode)`
- [ ] En `route_detail_page.dart`: el archivo importa `ruta_facil_app.dart`
