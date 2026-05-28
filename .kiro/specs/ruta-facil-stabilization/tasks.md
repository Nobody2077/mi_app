# Implementation Plan

- [x] 0. Extraer RouteRecordingController
  - Archivo: `lib/features/routes/presentation/route_recording_controller.dart`
  - Toda la logica de grabacion GPS extraida de `_AddRoutePageState`
  - `ChangeNotifier` con `start()`, `stop()`, `confirmTransportType()`, `dismissTransportConfirmation()`
  - `add_route_page.dart` refactorizado para usar el controller via listener en `initState`
  - El controller usa unicamente `Geolocator.getPositionStream` — nunca `getCurrentPosition`

- [x] 1. Fix Bug 1 — register Geolocator foreground service in AndroidManifest

  - [x] 1.1 Permisos agregados a `AndroidManifest.xml`:
    - `android.permission.FOREGROUND_SERVICE`
    - `android.permission.FOREGROUND_SERVICE_LOCATION`

  - [x] 1.2 Declaracion `<service>` agregada dentro de `<application>`:
    ```xml
    <service
        android:name="com.baseflow.geolocator.GeolocatorLocationService"
        android:enabled="true"
        android:exported="false"
        android:foregroundServiceType="location" />
    ```

  - [x] 1.3 `RouteRecordingController._buildLocationSettings()` actualizado:
    - Android: usa `AndroidSettings` con `ForegroundNotificationConfig` (titulo, texto, wakeLock)
    - iOS: usa `AppleSettings` con `showBackgroundLocationIndicator: true`
    - Otros: fallback a `LocationSettings` generico

- [x] 2. Mejorar UI de AddRoutePage — formulario de grabacion
  - Campos principales: "Nombre de la ruta" con helper explicativo, sindicato/linea opcionales (default "Desconocido"), descripcion opcional
  - Horario de servicio: auto-llenado desde `_recordingController.startedAt/endedAt` al detener grabacion
  - Variacion: dias como 7 chips (L-M-M-J-V-S-D) con pre-seleccion automatica del dia de grabacion, minimo 1 dia obligatorio
  - Causa: dropdown (Feria, Bloqueo/marcha, Hora pico, Feriado, Trameaje, Otro) + texto libre si "Otro"
  - Horas de variacion: pre-llenadas desde la grabacion al activar el switch
  - Eliminado campo "Puntos a mostrar"
  - Eliminados `_specialDaysController` y `_specialPointLimitController`

- [ ] 3. Implement Feature 1 — database seeding on first launch

  - [ ] 2.1 Write seeding property tests (BEFORE implementing)
    - Create `test/features/routes/data/local_route_repository_seeding_test.dart` usando `sqflite_ffi` para DB en memoria
    - Observar en codigo sin modificar: `getRoutes()` retorna lista vacia en DB fresca
    - Escribir property test: llamar `getRoutes()` N veces (N entre 1 y 10) nunca produce mas de 5 rutas con IDs en `_demoRouteIds`
    - Escribir example test: `addRoute(userRoute)` despues del seeding → `getRoutes()` retorna 6 rutas
    - Escribir example test: ningun ID de los 5 mock routes aparece en `getSavedRoutes()` (insertados con `saveRoute: false`)
    - _Requirements: Feature 1 — 2.3, 2.4, 2.5, 3.1_

  - [ ] 2.2 Expose mock routes as public static getter on `MockRouteRepository`
    - File: `lib/features/routes/data/mock_route_repository.dart`
    - Agregar despues de la declaracion de `_routes`:
      ```dart
      static List<TransitRoute> get routes => List.unmodifiable(_routes);
      ```
    - _Requirements: Feature 1 — 2.1_

  - [ ] 2.3 Add `_seedIfNeeded` method and call it from `getRoutes()`
    - File: `lib/features/routes/data/local_route_repository.dart`
    - Agregar import: `import 'mock_route_repository.dart';`
    - Agregar metodo privado `_seedIfNeeded(Database db)`:
      - Query `metadata` para `key = 'seeded_v2'`; si existe retornar inmediatamente (idempotente)
      - Si no: transaccion que inserta los 5 routes con `saveRoute: false` y luego inserta `('seeded_v2', '1')` en `metadata`
    - Modificar `getRoutes()`: agregar `await _seedIfNeeded(db);` como primera linea despues de `final db = await _db;`
    - _Requirements: Feature 1 — 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4_

  - [ ] 2.4 Verify seeding property tests pass after implementation
    - Re-run los MISMOS tests de la tarea 2.1
    - Verificar adicionalmente: DB fresca → `getRoutes()` retorna exactamente 5 rutas; segunda llamada → sigue siendo 5
    - **EXPECTED OUTCOME**: Todos los tests PASAN
    - _Requirements: Feature 1 — 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 3. Implement Feature 2 — Collector vs. Passenger mode

  - [ ] 3.1 Write widget tests for mode visibility (BEFORE implementing)
    - Create `test/features/home/presentation/home_page_collector_mode_test.dart`
    - Widget test: `HomePage` con `isCollectorMode = true` → boton "Grabar ruta" y card "Reportar" presentes
    - Widget test: `HomePage` con `isCollectorMode = false` → boton "Grabar ruta" y card "Reportar" ausentes; "Buscar", "Mapa", "Grabadas" presentes
    - Widget test: `RouteDetailPage` con `isCollectorMode = true` → boton "Borrar ruta" presente
    - Widget test: `RouteDetailPage` con `isCollectorMode = false` → boton "Borrar ruta" ausente
    - Widget test: long-press de 5 segundos en mascota → SnackBar mostrado y modo cambiado
    - Widget test: long-press de 2 segundos (suelta antes) → modo NO cambia
    - _Requirements: Feature 2 — 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.1_

  - [ ] 3.2 Add `isCollectorMode` to `AppSettings`
    - File: `lib/app/app_settings.dart`
    - Agregar `static const String _collectorModeKey = 'collector_mode';`
    - Agregar campo `late bool _isCollectorMode;`
    - En constructor: `_isCollectorMode = _preferences.getBool(_collectorModeKey) ?? true;`
    - Agregar getter: `bool get isCollectorMode => _isCollectorMode;`
    - Agregar metodo `setCollectorMode(bool value)` que persiste y llama `notifyListeners()`
    - _Requirements: Feature 2 — 2.1, 2.2, 3.2, 3.3_

  - [ ] 3.3 Update `home_page.dart` — conditional FAB, card "Reportar", and 5-second long-press toggle
    - File: `lib/features/home/presentation/home_page.dart`
    - Leer `AppSettingsScope.of(context).isCollectorMode` en `build()`
    - Envolver boton "Grabar ruta" en guard `if (isCollector)`
    - Envolver card "Reportar" en guard `if (isCollector)`
    - Convertir `_HeroHeader` a `StatefulWidget` con `Timer? _longPressTimer`
    - `onLongPressStart`: iniciar timer de 5 segundos que llama `setCollectorMode(!isCollectorMode)` y muestra SnackBar
    - `onLongPressEnd`: cancelar timer
    - _Requirements: Feature 2 — 2.3, 2.4, 2.6, 2.7, 2.8, 2.9, 3.1, 3.4_

  - [ ] 3.4 Update `route_detail_page.dart` — conditional "Borrar ruta" button
    - File: `lib/features/routes/presentation/route_detail_page.dart`
    - Leer `AppSettingsScope.of(context).isCollectorMode`
    - Envolver boton "Borrar ruta" en `if (settings.isCollectorMode)`
    - _Requirements: Feature 2 — 2.5, 2.6, 2.8, 3.1_

  - [ ] 3.5 Verify all collector/passenger mode widget tests pass
    - Re-run los MISMOS tests de la tarea 3.1
    - **EXPECTED OUTCOME**: Todos los tests PASAN
    - _Requirements: Feature 2 — 2.1 al 3.4_

- [ ] 4. Checkpoint — ensure all tests pass
  - Ejecutar `flutter test` y confirmar cero fallas
  - Verificar que los siguientes archivos de test pasan:
    - `test/android_manifest_test.dart`
    - `test/features/routes/data/local_route_repository_seeding_test.dart`
    - `test/features/home/presentation/home_page_collector_mode_test.dart`
  - Confirmar sin regresiones en tests pre-existentes
