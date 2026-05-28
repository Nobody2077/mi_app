# Ruta Fácil Stabilization — Design

## Overview

This document covers the technical design for one bugfix and two features in the **Ruta Fácil El Alto** Flutter app.

**Completed — RouteRecordingController Extraction:** All GPS recording logic has been extracted from `_AddRoutePageState` into `lib/features/routes/presentation/route_recording_controller.dart` (`ChangeNotifier`). The controller uses only `Geolocator.getPositionStream` — no `getCurrentPosition` call.

**Bug 1 — Background Recording Suspends (Foreground Service Missing):** On Android 14+, the OS refuses to promote the location listener to a foreground service because `AndroidManifest.xml` is missing the `<service>` declaration for `com.baseflow.geolocator.GeolocatorLocationService`. Fix: add the declaration inside `<application>`.

**Feature 1 — Database Seeding on First Launch:** On a fresh install the `routes` table is empty. `LocalRouteRepository.getRoutes()` must detect the absence of a `seeded_v2` metadata key and insert all 5 mock routes from `MockRouteRepository.routes` (with `saveRoute: false`) before returning results.

**Feature 2 — Collector vs. Passenger Mode (`isCollectorMode`):** Add a boolean flag to `AppSettings` that hides recording-related UI (FAB, "Reportar" card, "Borrar ruta" button) when `false`. A 5-second long-press on the mascot image in the home page header toggles the mode and shows a `SnackBar` confirmation.

---

## Glossary

- **`RouteRecordingController`**: `ChangeNotifier` at `lib/features/routes/presentation/route_recording_controller.dart` — manages GPS recording state and stream lifecycle.
- **`start()`**: `RouteRecordingController.start()` — requests permissions, starts `getPositionStream`, returns `RouteRecordingStartResult`.
- **`stop()`**: `RouteRecordingController.stop()` — cancels the stream subscription, sets `endedAt`.
- **`_addPosition(Position)`**: Private method in the controller that appends a coordinate to `_recordedPoints` after a 10-meter distance filter.
- **`getPositionStream`**: `Geolocator.getPositionStream` — the only source of coordinates during recording.
- **`GeolocatorLocationService`**: Android foreground service class from the `geolocator` plugin that keeps location updates alive in the background.
- **`seeded_v2`**: Metadata key in the SQLite `metadata` table that marks whether the 5 mock routes have been inserted.
- **`isCollectorMode`**: Boolean flag in `AppSettings` (default `true`) that controls visibility of recording-related UI.
- **`AppSettingsScope`**: `InheritedNotifier<AppSettings>` that exposes `AppSettings` to the widget tree.

---

## Bug 1: Background Recording Suspends

### Bug Condition

The bug manifests when the app is moved to the background on Android 14+ during an active recording session. The `GeolocatorLocationService` foreground service cannot be started because it is not declared in `AndroidManifest.xml`.

**Formal Specification:**
```
FUNCTION isBugCondition(session)
  INPUT: session — a RouteRecordingController recording session
  OUTPUT: boolean

  RETURN session.platform = Android14Plus
      AND session.wasBackgrounded = true
      AND session.recordedPoints.count STOPS GROWING after backgrounding
END FUNCTION
```

### Examples

- **Buggy**: User starts recording, backgrounds the app on a Pixel 8 (Android 14). After 2 minutes, "Puntos" counter is still 1. Average speed is 0.0 km/h.
- **Buggy**: User returns to foreground after 5 minutes. A straight-line gap appears in the polyline covering the missed distance.
- **Fixed**: Service declaration added. Foreground service starts when recording begins. Points accumulate continuously regardless of app visibility.
- **Not affected**: iOS uses `AppleSettings` with `showBackgroundLocationIndicator: true` — unaffected by this change.

### Preservation Requirements

- Foreground recording on Android continues to deliver updates at the configured interval (5 s / 12 m).
- iOS behavior is entirely unaffected (`AppleSettings` path is unchanged).
- `stop()` cancels the subscription and dismisses the foreground notification as before.
- The fix is backward-compatible with Android versions below 14.

### Root Cause

Android 14 (API 34) tightened enforcement of foreground service declarations. The `geolocator` plugin's `ForegroundNotificationConfig` instructs the plugin to use a foreground service, but Android will not start an undeclared service. The `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` permissions are already present in the manifest; only the `<service>` element is missing.

---

## Expected Behavior

### Bug 1 — Preservation Requirements

**Unchanged Behaviors:**
- `start()` returns `RouteRecordingStartResult.permissionDenied` when location permission is denied.
- `start()` returns `RouteRecordingStartResult.locationServiceDisabled` when the location service is off.
- `start()` returns `RouteRecordingStartResult.alreadyRecording` when called during an active session.
- The live stream's `_addPosition` calls continue to apply the 10-meter distance filter.
- `stop()` cancels the stream subscription and sets `endedAt`.
- Speed ≥ 12 km/h triggers `_needsTransportConfirmation = true` as before.

---

## Correctness Properties

Property 1: Bug Condition — Continuous Points Through Background (Android 14+)

_For any_ recording session on Android 14+ where the app is backgrounded, the fixed implementation (with the `<service>` declaration present) SHALL continue accumulating points in `_recordedPoints` at the configured interval, such that `recordedPoints.count` is strictly greater after a background period than it was at the moment of backgrounding.

**Validates: Requirements Bug 1 — 2.1, 2.2, 2.3**

Property 2: Preservation — Background Fix Does Not Affect iOS or Foreground Android

_For any_ recording session on iOS or on Android while the app remains in the foreground, the fixed implementation SHALL produce the same position update behavior as the original implementation, with no change to update frequency, distance filtering, or notification behavior.

**Validates: Requirements Bug 1 — 3.1, 3.2, 3.3, 3.4**

---

## Fix Implementation

### Fix 1: Add foreground service declaration to AndroidManifest

**File:** `android/app/src/main/AndroidManifest.xml`

**Change:** Add a `<service>` element inside `<application>`, after the closing `</activity>` tag and before the `<!-- Don't delete the meta-data below -->` comment.

**Exact diff:**
```diff
         </activity>
+        <!-- Geolocator foreground service — required for background location on Android 14+ -->
+        <service
+            android:name="com.baseflow.geolocator.GeolocatorLocationService"
+            android:enabled="true"
+            android:exported="false"
+            android:foregroundServiceType="location" />
         <!-- Don't delete the meta-data below.
```

No other changes to this file.

---

### Fix 2: Database seeding on first launch

**File:** `lib/features/routes/data/local_route_repository.dart`

**File:** `lib/features/routes/data/mock_route_repository.dart`

#### 2a. Expose mock routes as a public static getter

**In `mock_route_repository.dart`**, add after the `_routes` declaration:

```dart
static List<TransitRoute> get routes => List.unmodifiable(_routes);
```

#### 2b. Add `_seedIfNeeded` helper and call it from `getRoutes()`

**In `local_route_repository.dart`**, add a private method:

```dart
Future<void> _seedIfNeeded(Database db) async {
  final existing = await db.query(
    'metadata',
    where: 'key = ?',
    whereArgs: ['seeded_v2'],
    limit: 1,
  );
  if (existing.isNotEmpty) return;

  await db.transaction((txn) async {
    for (final route in MockRouteRepository.routes) {
      await _insertRoute(txn, route, saveRoute: false);
    }
    await txn.insert('metadata', {
      'key': 'seeded_v2',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
}
```

**Modify `getRoutes()`:**

```dart
@override
Future<List<TransitRoute>> getRoutes() async {
  final db = await _db;
  await _seedIfNeeded(db);                          // <-- added
  final routeRows = await db.query('routes', orderBy: 'created_at DESC');
  final routes = <TransitRoute>[];
  for (final row in routeRows) {
    routes.add(await _routeFromRow(db, row));
  }
  return routes;
}
```

**Add import** at the top:
```dart
import 'mock_route_repository.dart';
```

---

### Fix 3: Collector vs. Passenger mode (`isCollectorMode`)

#### 3a. `AppSettings` changes

**File:** `lib/app/app_settings.dart`

```dart
class AppSettings extends ChangeNotifier {
  AppSettings._(this._preferences) {
    final storedMode = _preferences.getString(_themeModeKey);
    _themeMode = storedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _isCollectorMode = _preferences.getBool(_collectorModeKey) ?? true;
  }

  static const String _themeModeKey = 'theme_mode';
  static const String _collectorModeKey = 'collector_mode';

  final SharedPreferences _preferences;
  late ThemeMode _themeMode;
  late bool _isCollectorMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isCollectorMode => _isCollectorMode;

  Future<void> setCollectorMode(bool value) async {
    _isCollectorMode = value;
    await _preferences.setBool(_collectorModeKey, value);
    notifyListeners();
  }
}
```

#### 3b. Home page changes

**File:** `lib/features/home/presentation/home_page.dart`

Leer `AppSettingsScope.of(context).isCollectorMode` y condicionar FAB y card "Reportar". Convertir `_HeroHeader` a `StatefulWidget` con `Timer? _longPressTimer`:

```dart
class _HeroHeaderState extends State<_HeroHeader> {
  Timer? _longPressTimer;

  void _onMascotLongPressStart(LongPressStartDetails _) {
    _longPressTimer = Timer(const Duration(seconds: 5), () {
      final settings = AppSettingsScope.of(context);
      final newValue = !settings.isCollectorMode;
      settings.setCollectorMode(newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? 'Modo Colector activado' : 'Modo Pasajero activado',
          ),
        ),
      );
    });
  }

  void _onMascotLongPressEnd(LongPressEndDetails _) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
```

#### 3c. Route detail page changes

**File:** `lib/features/routes/presentation/route_detail_page.dart`

```dart
final settings = AppSettingsScope.of(context);

if (settings.isCollectorMode)
  OutlinedButton.icon(
    onPressed: _confirmDeleteRoute,
    icon: const Icon(Icons.delete_outline),
    label: const Text('Borrar ruta'),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
  ),
```

---

## Testing Strategy

### Bug 1 — Foreground Service

**Test Cases:**
1. Parse `AndroidManifest.xml` (unfixed). Assert `<service android:name="com.baseflow.geolocator.GeolocatorLocationService">` is absent. (Confirms bug condition.)
2. Parse fixed `AndroidManifest.xml`. Assert service element is present with `android:foregroundServiceType="location"` and `android:exported="false"`. (Fix checking.)

### Feature 1 — Seeding

**Test Cases:**
1. **Idempotency**: Call `getRoutes()` twice on the same DB. Assert route count does not double.
2. **User route preservation**: `addRoute(userRoute)` after seeding → `getRoutes()` returns 6 routes.
3. **Saved routes**: After seeding, `getSavedRoutes()` returns zero seeded routes.
4. **Delete seeded route**: `deleteRoute('ceja-villa-adela')` → removed. Other 4 remain.
5. **Schema upgrade path**: Simulate v1→v2 upgrade → `seeded_v1` cleared → `getRoutes()` runs `seeded_v2` seeding → 5 routes returned.

### Feature 2 — Mode

**Test Cases:**
1. Load `AppSettings` with empty `SharedPreferences`. Assert `isCollectorMode = true`.
2. Call `setCollectorMode(false)`. Reload `AppSettings`. Assert `isCollectorMode = false`.
3. `HomePage` con `isCollectorMode = true` → "Grabar ruta" y "Reportar" presentes.
4. `HomePage` con `isCollectorMode = false` → "Grabar ruta" y "Reportar" ausentes.
5. `RouteDetailPage` con `isCollectorMode = true` → "Borrar ruta" presente.
6. `RouteDetailPage` con `isCollectorMode = false` → "Borrar ruta" ausente.
7. Long-press 5 s en mascota con `isCollectorMode = true` → SnackBar "Modo Pasajero activado".
8. Long-press 5 s en mascota con `isCollectorMode = false` → SnackBar "Modo Colector activado".
9. Long-press 2 s (suelta antes) → modo no cambia.
