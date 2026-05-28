# Requirements — Ruta Fácil Stabilization

## Introduction

This document defines the requirements for stabilizing the **Ruta Fácil El Alto** Flutter app. The `RouteRecordingController` has already been extracted from `AddRoutePage` (task 0 complete). The remaining work covers one critical bugfix and two new features:

1. **Bug 1 — Background Recording Suspends:** Register the Geolocator foreground service so Android 14+ does not suspend location tracking when the app is backgrounded.
2. **Feature 1 — Database Seeding:** Auto-populate the SQLite catalog with 5 mock routes on first launch so passengers see content immediately.
3. **Feature 2 — Collector vs. Passenger Mode:** Add an `isCollectorMode` flag that hides recording-related UI from passengers, toggled via a secret 5-second long-press on the mascot image.

---

## 1. Bug 1: Background Recording Suspends (Foreground Service Missing)

### 1.1 Problem Statement

On Android 14+, location tracking silently stops as soon as the app is moved to the background. The "Puntos" counter freezes at 1 and average speed stays at 0.0 km/h for the entire session. The `RouteRecordingController` configures a `ForegroundNotificationConfig` inside `AndroidSettings`, but the required `<service>` declaration for `com.baseflow.geolocator.GeolocatorLocationService` is absent from `android/app/src/main/AndroidManifest.xml`. Without this declaration, Android 14+ refuses to promote the location listener to a foreground service, causing the OS to suspend it when the app leaves the foreground.

### 1.2 Current Behavior (Defect)

1.1 WHEN the app is moved to the background on an Android 14+ device during an active recording session THEN the system stops delivering position updates to `_addPosition`, causing `_recordedPoints` to stop growing

1.2 WHEN position updates stop after backgrounding THEN the system shows a frozen "Puntos" counter (stays at 1) and an average speed of 0.0 km/h for the remainder of the session

1.3 WHEN the user returns the app to the foreground after a background period THEN the system resumes position updates but the gap in the path produces an incorrect straight-line segment across the missed distance

### 1.3 Expected Behavior (Correct)

2.1 WHEN the app is moved to the background during an active recording session on Android 14+ THEN the system SHALL continue delivering position updates to `_addPosition` without interruption, using the declared `GeolocatorLocationService` foreground service

2.2 WHEN the foreground service is active THEN the system SHALL display the persistent notification with title "Ruta Facil esta grabando" and text "El recorrido seguira registrandose hasta que presiones Terminar."

2.3 WHEN position updates continue uninterrupted through a background period THEN the system SHALL produce a continuous, gap-free polyline for the full duration of the recording session

### 1.4 Unchanged Behavior (Regression Prevention)

3.1 WHEN the app is in the foreground during recording THEN the system SHALL CONTINUE TO deliver position updates at the configured interval (every 5 seconds or 12-meter distance filter, whichever comes first)

3.2 WHEN the app is running on iOS THEN the system SHALL CONTINUE TO use `AppleSettings` with `showBackgroundLocationIndicator: true` and SHALL NOT be affected by this Android-specific fix

3.3 WHEN the user taps "Terminar" to stop recording THEN the system SHALL CONTINUE TO cancel the position stream subscription and dismiss the foreground service notification

3.4 WHEN the app is installed on Android versions below 14 THEN the system SHALL CONTINUE TO record in the background as before (the service declaration is backward-compatible)

### 1.5 Bug Condition (Formal)

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

## 2. Feature 1: Database Seeding on First Launch

### 2.1 Problem Statement

On first launch the `routes` SQLite table is empty, so passengers see a blank catalog with no routes to explore. The `MockRouteRepository` already contains 5 well-defined demo routes for El Alto. The `LocalRouteRepository` must detect an empty, unseeded database and automatically insert all 5 mock routes so the app is immediately useful out of the box. A `seeded_v2` metadata key tracks whether seeding has already been performed, preventing duplicate inserts on subsequent launches.

### 2.2 Current Behavior (Gap)

1.1 WHEN the app is launched for the first time on a fresh install THEN the system displays an empty route list because the `routes` table contains no rows

1.2 WHEN the database was previously at schema v1 and has been upgraded to v2 via `_upgradeSchema` THEN the system deletes the old demo routes and clears `seeded_v1`, leaving the `routes` table empty with no automatic re-seeding

### 2.3 Expected Behavior (Correct)

2.1 WHEN `getRoutes()` is called AND the `metadata` table does not contain a row with `key = 'seeded_v2'` THEN the system SHALL insert all 5 mock routes from `MockRouteRepository._routes` using `_insertRoute` with `saveRoute: false`, then insert `key = 'seeded_v2'` into the `metadata` table

2.2 WHEN seeding completes THEN the system SHALL return the 5 seeded routes as the result of `getRoutes()`, ordered by `created_at DESC`

2.3 WHEN `getRoutes()` is called on a subsequent launch AND `metadata` already contains `key = 'seeded_v2'` THEN the system SHALL skip seeding and return the existing routes from the database without modification

2.4 WHEN a user has recorded and saved additional routes after seeding THEN the system SHALL CONTINUE TO return all routes (seeded + user-recorded) from `getRoutes()` without re-seeding or overwriting user data

2.5 WHEN seeding inserts the 5 mock routes THEN the system SHALL insert them with `saveRoute: false` so none of the demo routes appear in the "Guardadas" (saved routes) list by default

### 2.4 Unchanged Behavior (Regression Prevention)

3.1 WHEN `addRoute(route)` is called with a user-recorded route THEN the system SHALL CONTINUE TO insert the route with `saveRoute: true` and make it appear in `getSavedRoutes()`

3.2 WHEN `deleteRoute(routeId)` is called for a seeded demo route THEN the system SHALL CONTINUE TO delete it from all tables including `route_stops`, `route_points`, `fare_rules`, `schedule_rules`, and `saved_routes`

3.3 WHEN the database is opened for the first time (schema v1 → v2 upgrade path) THEN the system SHALL CONTINUE TO execute `_upgradeSchema` which deletes old demo routes and clears `seeded_v1` before the new `seeded_v2` seeding runs

3.4 WHEN `toggleSavedRoute(routeId)` is called for a seeded demo route THEN the system SHALL CONTINUE TO add or remove it from `saved_routes` correctly

### 2.5 Mock Routes to Seed

The following 5 routes from `MockRouteRepository` must be inserted:

| ID | Name | Type | Fare |
|----|------|------|------|
| `ceja-villa-adela` | Linea 101 - Ceja a Villa Adela | minibus | Bs. 2.00 |
| `ceja-senkata` | Trufi 42 - Ceja a Senkata | trufi | Bs. 2.50 |
| `ceja-rio-seco` | Micro A - Ceja a Rio Seco | micro | Bs. 1.50 |
| `piloto-casa-u` | Piloto Casa - Universidad | minibus | Bs. 2.00 |
| `linea-204-ballivian-ceja` | Linea 204 - Gral. Camacho a Av. 6 de Marzo | minibus | Bs. 2.50 (with fare rules and Thursday/Sunday feria schedule rule) |

---

## 3. Feature 2: Collector vs. Passenger Mode (`isCollectorMode`)

### 3.1 Problem Statement

The app serves two distinct user personas: **Route Collectors** who record GPS routes in the field, and **Passengers** who only search and view routes. Currently all users see recording-related UI (the "Grabar ruta" button, "Reportar" card, "Borrar ruta" button, and admin actions) regardless of their role. A boolean `isCollectorMode` flag must be added to `AppSettings` to control visibility of these elements. The flag defaults to `true` (collector mode active) for development and field use. A secret 5-second long-press on the mascot image in the home page header toggles the mode without a confirmation dialog.

### 3.2 Current Behavior (Gap)

1.1 WHEN `isCollectorMode` does not exist in `AppSettings` THEN the system always shows recording-related UI elements (FAB, "Reportar" card, "Borrar ruta" button) to all users regardless of their role

1.2 WHEN a passenger user opens the app THEN the system displays the "Grabar ruta" floating action button and "Reportar" action card, which are irrelevant and confusing for their use case

### 3.3 Expected Behavior (Correct)

**AppSettings**

2.1 WHEN `AppSettings` is loaded THEN the system SHALL read the `'collector_mode'` key from `SharedPreferences` and expose it as `bool isCollectorMode`, defaulting to `true` if the key is absent

2.2 WHEN `setCollectorMode(bool value)` is called THEN the system SHALL persist the value under key `'collector_mode'` in `SharedPreferences`, update `isCollectorMode`, and call `notifyListeners()`

**Home Page**

2.3 WHEN `isCollectorMode` is `false` THEN the system SHALL hide the "Grabar ruta" floating action button on the home page

2.4 WHEN `isCollectorMode` is `false` THEN the system SHALL hide the "Reportar" action card on the home page

2.5 WHEN `isCollectorMode` is `true` THEN the system SHALL display the "Grabar ruta" button and "Reportar" card as they currently appear

**Route Detail Page**

2.6 WHEN `isCollectorMode` is `false` THEN the system SHALL hide the "Borrar ruta" button on the route detail page

2.7 WHEN `isCollectorMode` is `false` THEN the system SHALL hide any other administrative or edit action buttons on the route detail page

2.8 WHEN `isCollectorMode` is `true` THEN the system SHALL display all administrative buttons as they currently appear

**Secret Toggle**

2.9 WHEN the user long-presses the mascot/logo image in the home page header for 5 continuous seconds THEN the system SHALL toggle `isCollectorMode` to its opposite value

2.10 WHEN the mode is toggled to `true` via the long-press gesture THEN the system SHALL display a `SnackBar` with the message "Modo Colector activado"

2.11 WHEN the mode is toggled to `false` via the long-press gesture THEN the system SHALL display a `SnackBar` with the message "Modo Pasajero activado"

2.12 WHEN the mode is toggled THEN the system SHALL NOT show a confirmation dialog; the toggle SHALL take effect immediately

**Search and Map**

2.13 WHEN `isCollectorMode` is `false` THEN the system SHALL CONTINUE TO display the route search view fully accessible to passengers

2.14 WHEN `isCollectorMode` is `false` THEN the system SHALL CONTINUE TO display the map view fully accessible to passengers

### 3.4 Unchanged Behavior (Regression Prevention)

3.1 WHEN `isCollectorMode` is `true` (default) THEN the system SHALL CONTINUE TO show the "Grabar ruta" FAB, "Reportar" card, and all admin buttons exactly as they currently appear

3.2 WHEN `AppSettings.setThemeMode(mode)` is called THEN the system SHALL CONTINUE TO persist and apply the theme mode independently of `isCollectorMode`

3.3 WHEN the app is restarted after toggling `isCollectorMode` THEN the system SHALL CONTINUE TO restore the persisted value from `SharedPreferences` so the mode survives app restarts

3.4 WHEN `isCollectorMode` is `false` THEN the system SHALL CONTINUE TO allow passengers to view route details, browse the map, and use all search functionality without any restriction
