# Bugfix Requirements Document

## Introduction

This document covers one critical bugfix and two new features for the **Ruta Fácil El Alto** Flutter app.

**Completed:** `RouteRecordingController` ha sido extraido de `AddRoutePage` a `lib/features/routes/presentation/route_recording_controller.dart`. El controller usa unicamente `Geolocator.getPositionStream` — sin `getCurrentPosition`.

El bug causa falla silenciosa en el seguimiento de ubicacion en segundo plano (los updates de ubicacion se detienen cuando la app pasa al fondo en Android 14+). Las dos features agregan seeding de la base de datos en el primer lanzamiento y un modo Colector/Pasajero que oculta la UI de grabacion a los usuarios finales.

---

## Bug 1: Background Recording Suspends (Foreground Service Missing)

### Introduction

On Android 14+, location tracking silently stops as soon as the app is moved to the background. The "Puntos" counter freezes at 1 and average speed stays at 0.0 km/h for the entire session. The `RouteRecordingController` configures a `ForegroundNotificationConfig` inside `AndroidSettings`, but the required `<service>` declaration for `com.baseflow.geolocator.GeolocatorLocationService` is absent from `android/app/src/main/AndroidManifest.xml`. Without this declaration, Android 14+ refuses to promote the location listener to a foreground service, causing the OS to suspend it when the app leaves the foreground.

### Bug Analysis

#### Current Behavior (Defect)

1.1 WHEN the app is moved to the background on an Android 14+ device during an active recording session THEN the system stops delivering position updates to `_addPosition`, causing `_recordedPoints` to stop growing

1.2 WHEN position updates stop after backgrounding THEN the system shows a frozen "Puntos" counter (stays at 1) and an average speed of 0.0 km/h for the remainder of the session

1.3 WHEN the user returns the app to the foreground after a background period THEN the system resumes position updates but the gap in the path produces an incorrect straight-line segment across the missed distance

#### Expected Behavior (Correct)

2.1 WHEN the app is moved to the background during an active recording session on Android 14+ THEN the system SHALL continue delivering position updates to `_addPosition` without interruption, using the declared `GeolocatorLocationService` foreground service

2.2 WHEN the foreground service is active THEN the system SHALL display the persistent notification with title "Ruta Facil esta grabando" and text "El recorrido seguira registrandose hasta que presiones Terminar."

2.3 WHEN position updates continue uninterrupted through a background period THEN the system SHALL produce a continuous, gap-free polyline for the full duration of the recording session

#### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app is in the foreground during recording THEN the system SHALL CONTINUE TO deliver position updates at the configured interval (every 5 seconds or 12-meter distance filter, whichever comes first)

3.2 WHEN the app is running on iOS THEN the system SHALL CONTINUE TO use `AppleSettings` with `showBackgroundLocationIndicator: true` and SHALL NOT be affected by this Android-specific fix

3.3 WHEN the user taps "Terminar" to stop recording THEN the system SHALL CONTINUE TO cancel the position stream subscription and dismiss the foreground service notification

3.4 WHEN the app is installed on Android versions below 14 THEN the system SHALL CONTINUE TO record in the background as before (the service declaration is backward-compatible)

### Bug Condition (Formal)

```pascal
FUNCTION isBugCondition(X)
  INPUT: X — a route recording session
  OUTPUT: boolean

  RETURN X.platform = Android14Plus
      AND X.wasBackgrounded = true
      AND X.recordedPoints.count = 1
END FUNCTION
```

```pascal
// Property: Fix Checking — points must continue accumulating after backgrounding
FOR ALL X WHERE isBugCondition(X) DO
  result ← recordAfterBackground'(X)   // fixed implementation
  ASSERT result.recordedPoints.count > 1
END FOR

// Property: Preservation Checking — foreground recording unchanged
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT recordAfterBackground(X) = recordAfterBackground'(X)
END FOR
```

---

## Feature 1: Database Seeding on First Launch

### Introduction

On first launch the `routes` SQLite table is empty, so passengers see a blank catalog with no routes to explore. The `MockRouteRepository` already contains 5 well-defined demo routes for El Alto. The `LocalRouteRepository` must detect an empty, unseeded database and automatically insert all 5 mock routes so the app is immediately useful out of the box. A `seeded_v2` metadata key tracks whether seeding has already been performed, preventing duplicate inserts on subsequent launches.

### Requirements

#### Current Behavior (Gap)

1.1 WHEN the app is launched for the first time on a fresh install THEN the system displays an empty route list because the `routes` table contains no rows

1.2 WHEN the database was previously at schema v1 and has been upgraded to v2 via `_upgradeSchema` THEN the system deletes the old demo routes and clears `seeded_v1`, leaving the `routes` table empty with no automatic re-seeding

#### Expected Behavior (Correct)

2.1 WHEN `getRoutes()` is called AND the `metadata` table does not contain a row with `key = 'seeded_v2'` THEN the system SHALL insert all 5 mock routes from `MockRouteRepository.routes` using `_insertRoute` with `saveRoute: false`, then insert `key = 'seeded_v2'` into the `metadata` table

2.2 WHEN seeding completes THEN the system SHALL return the 5 seeded routes as the result of `getRoutes()`, ordered by `created_at DESC`

2.3 WHEN `getRoutes()` is called on a subsequent launch AND `metadata` already contains `key = 'seeded_v2'` THEN the system SHALL skip seeding and return the existing routes from the database without modification

2.4 WHEN a user has recorded and saved additional routes after seeding THEN the system SHALL CONTINUE TO return all routes (seeded + user-recorded) from `getRoutes()` without re-seeding or overwriting user data

2.5 WHEN seeding inserts the 5 mock routes THEN the system SHALL insert them with `saveRoute: false` so none of the demo routes appear in the "Guardadas" list by default

#### Unchanged Behavior (Regression Prevention)

3.1 WHEN `addRoute(route)` is called with a user-recorded route THEN the system SHALL CONTINUE TO insert the route with `saveRoute: true`

3.2 WHEN `deleteRoute(routeId)` is called for a seeded demo route THEN the system SHALL CONTINUE TO delete it from all tables

3.3 WHEN the database is opened for the first time (schema v1 → v2 upgrade path) THEN the system SHALL CONTINUE TO execute `_upgradeSchema` before `seeded_v2` seeding runs

3.4 WHEN `toggleSavedRoute(routeId)` is called for a seeded demo route THEN the system SHALL CONTINUE TO add or remove it from `saved_routes` correctly

### Mock Routes to Seed

| ID | Name | Type | Fare |
|----|------|------|------|
| `ceja-villa-adela` | Linea 101 - Ceja a Villa Adela | minibus | Bs. 2.00 |
| `ceja-senkata` | Trufi 42 - Ceja a Senkata | trufi | Bs. 2.50 |
| `ceja-rio-seco` | Micro A - Ceja a Rio Seco | micro | Bs. 1.50 |
| `piloto-casa-u` | Piloto Casa - Universidad | minibus | Bs. 2.00 |
| `linea-204-ballivian-ceja` | Linea 204 - Gral. Camacho a Av. 6 de Marzo | minibus | Bs. 2.50 |

---

## Feature 2: Collector vs. Passenger Mode (`isCollectorMode`)

### Introduction

The app serves two distinct user personas: **Route Collectors** who record GPS routes in the field, and **Passengers** who only search and view routes. A boolean `isCollectorMode` flag in `AppSettings` controls visibility of recording-related UI. The flag defaults to `true`. A secret 5-second long-press on the mascot image toggles the mode.

### Requirements

#### Current Behavior (Gap)

1.1 WHEN `isCollectorMode` does not exist in `AppSettings` THEN the system always shows recording-related UI elements to all users

1.2 WHEN a passenger user opens the app THEN the system displays the "Grabar ruta" FAB and "Reportar" card, which are irrelevant for their use case

#### Expected Behavior (Correct)

2.1 WHEN `AppSettings` is loaded THEN `isCollectorMode` defaults to `true` if `'collector_mode'` key is absent in `SharedPreferences`

2.2 WHEN `setCollectorMode(bool value)` is called THEN the value is persisted and `notifyListeners()` called

2.3 WHEN `isCollectorMode` is `false` THEN "Grabar ruta" FAB on home page is hidden

2.4 WHEN `isCollectorMode` is `false` THEN "Reportar" card on home page is hidden

2.5 WHEN `isCollectorMode` is `false` THEN "Borrar ruta" button on route detail page is hidden

2.6 WHEN `isCollectorMode` is `true` THEN all admin UI is shown as currently

2.7 WHEN user long-presses mascot for 5 seconds THEN `isCollectorMode` is toggled

2.8 WHEN toggled to `true` THEN SnackBar shows "Modo Colector activado"; when toggled to `false` → "Modo Pasajero activado"

2.9 WHEN `isCollectorMode` is `false` THEN search, map, and route browsing remain fully accessible

#### Unchanged Behavior (Regression Prevention)

3.1 WHEN `isCollectorMode` is `true` THEN all current UI is shown unchanged

3.2 WHEN `setThemeMode(mode)` is called THEN theme persists independently of `isCollectorMode`

3.3 WHEN app restarts after toggling THEN persisted value is restored from `SharedPreferences`

3.4 WHEN `isCollectorMode` is `false` THEN passengers can still view route details, map, and search
