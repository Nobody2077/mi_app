# Plan de implementación — Rediseño UI Pasajero

> **Para agentes de código:** Este spec solo toca 3 archivos.
> Lee `design.md` para los diffs exactos antes de implementar cada tarea.
> Todo cambio es condicional por `isCollectorMode` — el modo colector no debe cambiar.

---

## Resumen de archivos a modificar

| Archivo | Tareas |
|---|---|
| `lib/features/routes/presentation/map_page.dart` | Tareas 1, 2, 3, 4, 5 |
| `lib/features/routes/presentation/route_detail_page.dart` | Tareas 6, 7, 8 |
| `lib/features/routes/presentation/search_destination_page.dart` | Tarea 9 |

---

## Tarea 1 — Ocultar botón "Agregar ruta" para pasajeros en MapPage

**Archivo:** `lib/features/routes/presentation/map_page.dart`

**Descripción:** El `IconButton` de "Agregar ruta" en el `AppBar` solo debe ser visible cuando `isCollectorMode == true`.

**Pasos:**
1. Agregar import al inicio del archivo: `import '../../../app/ruta_facil_app.dart';`
2. En `_MapPageState.build()`, leer `final settings = AppSettingsScope.of(context);`
3. Envolver el `IconButton` en `if (settings.isCollectorMode)` dentro del array `actions`

**NO TOCAR:** El `onPressed` del botón, `_loadMapData()`, ni ningún otro elemento del `AppBar`.

**Verificación:**
- Con `isCollectorMode = false`: `AppBar.actions` no contiene el `IconButton`
- Con `isCollectorMode = true`: comportamiento actual sin cambios

---

## Tarea 2 — Color de polilínea por tipo de transporte

**Archivo:** `lib/features/routes/presentation/map_page.dart`

**Descripción:** La polilínea usa `Colors.blue` hardcoded. Debe usar el color de `AppTheme` según el tipo de transporte de la ruta seleccionada.

**Pasos:**
1. En `_MapPageState`, verificar si ya existe `_colorFor(TransportType)`. Si no existe, agregar:
   ```dart
   Color _colorFor(TransportType type) {
     return switch (type) {
       TransportType.minibus => AppTheme.minibus,
       TransportType.trufi   => AppTheme.trufi,
       TransportType.micro   => AppTheme.micro,
     };
   }
   ```
2. En `PolylineLayer`, cambiar `color: Colors.blue` por `color: _colorFor(selectedRoute.transportType)`

**NO TOCAR:** `strokeWidth`, `points`, ni ningún otro parámetro de `Polyline`.

**Verificación:**
- Ruta de tipo `minibus` → polilínea color `#22577A`
- Ruta de tipo `trufi` → polilínea color `#2D936C`
- Ruta de tipo `micro` → polilínea color `#E89A00`

---

## Tarea 3 — Visualización del recorrido (actualizada 2026-06-10)

**Archivo:** `lib/features/routes/presentation/passenger_map_page.dart`

> **Reemplaza la tarea original de "marcadores de paradas".** Los puntos del
> path son muestras GPS, no paradas; el marcador por punto se descartó porque
> al alejar el zoom formaba una nube ilegible. **Ya implementada.**

**Descripción:** El recorrido seleccionado se dibuja como polilínea doble (casing blanco de 9 px + línea de color del transporte de 5 px), con un círculo blanco de salida en `path.first` y un pin tipo gota con bandera a cuadros (`BusMarker`) en `path.last`. Sin marcadores intermedios.

**Verificación:**
- Al seleccionar una ruta, se ve una línea limpia a cualquier nivel de zoom
- Solo hay dos marcadores de recorrido: salida (círculo) y llegada (bandera)
- Los buses usan el pin `BusMarker` con el ícono del tipo de transporte

---

## Tarea 4 — Layout del mapa: mapa ampliado con lista horizontal de rutas

**Archivo:** `lib/features/routes/presentation/map_page.dart`

**Descripción:** Reorganizar el `Column` del body para que en modo pasajero el mapa ocupe más espacio y la selección de ruta sea una lista horizontal de `ActionChip` debajo del mapa. En modo colector, mantener el layout actual.

**Pasos:**
1. En `_MapPageState.build()`, leer `settings.isCollectorMode`
2. Condicionar el body: si `isCollectorMode == true`, usar el layout actual sin cambios
3. Si `isCollectorMode == false`, usar el nuevo layout:
   - Fila de chips de filtro (misma lógica que ahora, pero sin el título "Transportes públicos de El Alto" y sin el `DropdownButtonFormField`)
   - `Flexible(flex: 3, child: FlutterMap(...))` para el mapa
   - `SizedBox(height: 48)` con `ListView.builder` horizontal de `ActionChip` para las rutas visibles
   - `_EmptyMapSummary` o `_MapSummary` como antes

Ver `design.md` sección 2.3.4 para el código completo del nuevo layout.

**NO TOCAR:** El layout en modo colector, `_loadMapData()`, `_showRoute()`, `_selectTransportType()`, `_selectRoute()`, ni ninguna lógica de datos.

**Verificación:**
- `isCollectorMode = false`: mapa ocupa la mayor parte de pantalla, se ven chips de rutas debajo
- `isCollectorMode = true`: layout idéntico al actual con panel de controles y dropdown
- Seleccionar un `ActionChip` de ruta carga la ruta correctamente en el mapa

---

## Tarea 5 — `_MapSummary` orientado al pasajero

**Archivo:** `lib/features/routes/presentation/map_page.dart`

**Descripción:** El panel inferior `_MapSummary` debe mostrar datos diferentes según el modo. Para pasajero: chips de tipo/tarifa/horario, nota de feria si aplica, leyenda con paradas. Para colector: comportamiento actual.

**Pasos:**
1. Agregar parámetro `required bool isCollectorMode` a la clase `_MapSummary`
2. Pasar `isCollectorMode: settings.isCollectorMode` al construir `_MapSummary` en `build()`
3. En `_MapSummary.build()`:
   - Reemplazar la línea de texto `'Bs X.X - HH:MM - N buses'` por chips: `[Tipo][Bs X.X][Horario]`
   - Agregar bloque de nota de feria (banner ámbar) condicionado a `activeInfo?.isModified == true`
   - Ocultar `'Grabada: ...'` y `'Causa: ...'` cuando `!isCollectorMode`

Ver `design.md` sección 2.3.5 para el código completo.

**NO TOCAR:** El botón "Detalle" y su `onOpenDetail`, la estructura general del `Material`, ni `_LegendItem`.

**Verificación:**
- `isCollectorMode = false`: no aparece texto "Grabada:" ni "Causa:" en el summary
- `isCollectorMode = false` con ruta de feria activa: banner ámbar visible
- `isCollectorMode = true`: summary idéntico al actual

---

## Tarea 6 — Ocultar campos de colector en RouteDetailPage

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Descripción:** Las fechas de grabación y la causa de variación solo deben mostrarse cuando `isCollectorMode == true`.

**Pasos:**
1. Agregar import: `import '../../../app/ruta_facil_app.dart';`
2. En `_RouteDetailPageState.build()`, agregar:
   ```dart
   final settings = AppSettingsScope.of(context);
   final isPassenger = !settings.isCollectorMode;
   ```
3. Envolver los siguientes bloques con `if (!isPassenger)`:
   - `if (route.recordedStartedAt != null) Text('Grabacion: ...')`
   - `if (route.recordedEndedAt != null) Text('Fin: ...')`
   - `if (route.variationReason.isNotEmpty) Text('Causa observada: ...')`

**NO TOCAR:** Los demás campos de la Card (nombre, chips, origen/destino, tarifa, horario, ETA, descripción, nota de disponibilidad).

**Verificación:**
- `isCollectorMode = false`: ningún texto "Grabacion:", "Fin:", "Causa observada:" visible
- `isCollectorMode = true`: todos los campos visibles como hoy

---

## Tarea 7 — Banner de desvío de feria y tarifa simplificada en RouteDetailPage

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Descripción:** Para pasajeros, mostrar la tarifa activa una sola vez, y un banner ámbar cuando hay desvío de feria activo.

**Pasos (depende de Tarea 6 — debe ejecutarse después):**

1. **Tarifa simplificada para pasajero** — Reemplazar las dos líneas de tarifa:
   - Si `isPassenger`: mostrar `activeInfo.fareBs` una sola vez; si difiere de `route.fareBs`, agregar nota en `bodySmall`
   - Si `!isPassenger`: mantener ambas líneas actuales

2. **Banner de feria** — Insertar después del bloque de chips (tipo/línea/sindicato), antes del bloque de tarifa:
   ```dart
   if (isPassenger && activeInfo.isModified) ...[
     const SizedBox(height: 10),
     Container(
       width: double.infinity,
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: AppTheme.micro.withValues(alpha: 0.12),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: AppTheme.micro.withValues(alpha: 0.5)),
       ),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           PhosphorIcon(PhosphorIcons.warning(PhosphorIconsStyle.fill),
               color: AppTheme.micro, size: 18),
           const SizedBox(width: 8),
           Expanded(
             child: Text(
               activeInfo.note,
               style: TextStyle(color: AppTheme.micro, fontWeight: FontWeight.w500),
             ),
           ),
         ],
       ),
     ),
   ],
   ```
   Agregar import: `import '../../../app/app_theme.dart';`

**NO TOCAR:** La lógica de `_availabilityService.evaluate()`, el modelo `RouteAvailabilityInfo`, ni los campos de paradas o tarifas por tramo.

**Verificación:**
- `isCollectorMode = false` + ruta sin feria: solo una línea de tarifa, sin banner
- `isCollectorMode = false` + ruta con feria activa (ej. `linea-204-ballivian-ceja` un jueves): banner ámbar visible con el texto de la nota
- `isCollectorMode = true`: dos líneas de tarifa, sin banner, igual que hoy

---

## Tarea 8 — Jerarquía de botones en RouteDetailPage para pasajeros

**Archivo:** `lib/features/routes/presentation/route_detail_page.dart`

**Descripción:** Para pasajeros, ocultar "Exportar" y "Borrar ruta". Los botones visibles son: "Ver mapa" (primario), bookmark, "Reportar".

**Pasos (depende de Tarea 6):**

Reemplazar el bloque de botones actual con la versión condicional del `design.md` sección 3.2.

En resumen:
- `FilledButton` "Ver mapa" + `IconButton.filledTonal` bookmark → siempre visibles
- `OutlinedButton` "Reportar" → siempre visible
- `OutlinedButton` "Exportar" → solo `if (settings.isCollectorMode)`
- `OutlinedButton` "Borrar ruta" → solo `if (settings.isCollectorMode)`

**NO TOCAR:** `_confirmDeleteRoute()`, `_exportRoute()`, `_toggleSaved()`, `_showReportDialog()`, la lógica de cualquier botón.

**Verificación:**
- `isCollectorMode = false`: `find('Borrar ruta')` → vacío; `find('Exportar o compartir ruta')` → vacío
- `isCollectorMode = false`: `find('Ver mapa')` → presente; `find('Reportar cambio o problema')` → presente
- `isCollectorMode = true`: todos los botones presentes igual que hoy

---

## Tarea 9 — ListTile mejorado en SearchDestinationPage

**Archivo:** `lib/features/routes/presentation/search_destination_page.dart`

**Descripción:** Mejorar el ítem de resultado con ícono coloreado, subtitle `origin → destination` y chip de tarifa.

**Pasos:**
1. Agregar import: `import '../../../app/app_theme.dart';`
2. Agregar helper `_colorFor(TransportType)` en `_SearchDestinationPageState`
3. En `ListView.builder`, reemplazar el `ListTile` actual:
   - `leading`: `Container` 40x40 con `color: _colorFor(type).withValues(alpha: 0.15)` y `Icon` del tipo
   - `title`: `Text(route.name)` — igual que ahora
   - `subtitle`: `Text('${route.origin} → ${route.destination}')` — solo dos extremos
   - `trailing`: `Chip(label: Text('Bs ${route.fareBs.toStringAsFixed(1)}'))` con `visualDensity: VisualDensity.compact`

**NO TOCAR:** El `onTap`, `_loadRoutes()`, los chips de filtro, el autocomplete, `_originSuggestions()`, `_destinationSuggestions()`.

**Verificación:**
- Resultado muestra `origin → destination`, NO la cadena de paradas
- El `leading` tiene el color del tipo de transporte
- El `trailing` muestra el chip de tarifa
- Tapping en el resultado navega a `RouteDetailPage` igual que antes

---

## Orden de ejecución recomendado

```
Tarea 1 (AppBar)
    ↓
Tarea 2 (color polilínea) ─── paralelo con ─── Tarea 9 (search ListTile)
    ↓
Tarea 3 (stop markers)
    ↓
Tarea 4 (layout mapa)
    ↓
Tarea 5 (MapSummary)

Tarea 6 (ocultar campos colector)  ← prerequisito para 7 y 8
    ↓
Tarea 7 (banner feria + tarifa)
    ↓
Tarea 8 (jerarquía botones)
```

Las tareas de `map_page.dart` y `route_detail_page.dart` son independientes entre sí. Las tareas de `route_detail_page.dart` deben hacerse en orden (6 → 7 → 8).

---

## Checkpoint final

- [ ] `flutter analyze` — cero errores, cero warnings nuevos
- [ ] `flutter build apk --debug` — compila sin errores
- [ ] Mapa de pasajero (`PassengerMapPage`): mapa ampliado, polilínea con color y casing blanco, marcadores de salida/llegada (sin puntos intermedios), buses con pin `BusMarker`, summary limpio
- [ ] MapPage con `isCollectorMode = true`: layout idéntico al original
- [ ] RouteDetailPage con `isCollectorMode = false`: sin fechas de grabación, sin Exportar, sin Borrar ruta, con banner feria si aplica
- [ ] RouteDetailPage con `isCollectorMode = true`: idéntico al original
- [ ] SearchDestinationPage: subtitle muestra `origin → destination`, leading con color, trailing con tarifa
