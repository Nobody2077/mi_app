# Design — Rediseño UI Pasajero (Ruta Fácil El Alto)

> **Para agentes de código:** Este spec solo toca 3 archivos de presentación.
> Lee "NO TOCAR" en cada sección antes de implementar.
> Todo depende de `AppSettingsScope.of(context).isCollectorMode` — ya está wired en la app.

> **Estado real de implementación (2026-06-10):** El mapa del pasajero se
> implementó como página dedicada `PassengerMapPage`
> (`presentation/passenger_map_page.dart`); `MapPage` quedó como mapa del
> colector. Las secciones de este documento que dicen "`MapPage` en modo
> pasajero" aplican a `PassengerMapPage`. Los buses de ambos mapas usan el
> widget compartido `BusMarker` (pin tipo gota, `presentation/widgets/bus_marker.dart`)
> y el recorrido se dibuja según la sección 2.3.3 actualizada (línea con
> casing + salida/llegada, sin marcadores por punto).

---

## 1. Contexto y restricciones globales

### Cómo funciona el modo pasajero

```dart
// AppSettings ya tiene (NO MODIFICAR):
bool get isCollectorMode => _isCollectorMode;  // default false

// Acceso en cualquier widget:
final settings = AppSettingsScope.of(context);
if (!settings.isCollectorMode) { /* lógica pasajero */ }
```

`AppSettingsScope` es un `InheritedNotifier<AppSettings>` definido en `lib/app/ruta_facil_app.dart`. Está disponible en toda la app sin necesidad de imports adicionales de `app_settings.dart` — solo importar `ruta_facil_app.dart`.

### Colores de transporte (AppTheme — NO MODIFICAR)

```dart
// lib/app/app_theme.dart
static const Color minibus = Color(0xFF22577A);  // azul oscuro
static const Color trufi   = Color(0xFF2D936C);  // verde
static const Color micro   = Color(0xFFE89A00);  // ámbar/naranja
```

### Archivos a modificar

| Archivo | Cambios |
|---|---|
| `lib/features/routes/presentation/map_page.dart` | MapPage, _MapSummary, polilínea, botón AppBar |
| `lib/features/routes/presentation/route_detail_page.dart` | Info pasajero, banner feria, jerarquía botones |
| `lib/features/routes/presentation/search_destination_page.dart` | ListTile mejorado |

### Archivos PROHIBIDOS de modificar

- `lib/features/routes/presentation/add_route_page.dart`
- `lib/features/routes/presentation/routes_page.dart`
- `lib/features/routes/presentation/route_recording_controller.dart`
- `lib/app/app_settings.dart`
- `lib/app/app_theme.dart`
- `lib/features/home/presentation/home_page.dart`
- Cualquier archivo en `domain/`

---

## 2. MapPage — rediseño completo para pasajero

### 2.1 Problemas actuales

```
ACTUAL:
┌─────────────────────────────────────────┐
│ AppBar: Mapa de transportes  [📍 Agregar]│  ← botón colector visible a pasajeros
├─────────────────────────────────────────┤
│ Transportes públicos de El Alto         │
│ [Todos][🚐 Minibus][🚕 Trufi][🚌 Micro] │
│ ┌─────────────────────────────────────┐ │
│ │ Selecciona una ruta    [dropdown ▼] │ │  ← dropdown torpe en mobile
│ └─────────────────────────────────────┘ │
│ ←──── el panel de arriba consume ~200px ─→│
├─────────────────────────────────────────┤
│                                         │
│          MAPA (espacio reducido)        │  ← mapa pequeño
│                                         │
├─────────────────────────────────────────┤
│ Nombre de ruta               [N min ⏱] │
│ Tipo Línea - Sindicato                  │
│ Bs X.X - HH:MM-HH:MM - N buses         │
│ Grabada: dd/mm/yyyy        ← COLECTOR   │
│ Causa: texto               ← COLECTOR   │
│ [● Recorrido][● Bus activo][Detalle]    │
└─────────────────────────────────────────┘
```

### 2.2 Diseño objetivo para pasajero

```
OBJETIVO (isCollectorMode == false):
┌─────────────────────────────────────────┐
│ AppBar: Mapa de transportes             │  ← sin botón Agregar ruta
├─────────────────────────────────────────┤
│ [Todos][🚐 Minibus][🚕 Trufi][🚌 Micro] │  ← chips en fila horizontal scrollable
│                                         │
│                                         │
│                                         │
│          MAPA (65%+ de altura)          │  ← mapa ampliado
│                                         │
│      ○━━━━━━━━━━━━━━━━━━━━⚑            │  ← línea con casing blanco,
│       salida          llegada           │     sin puntos intermedios
│                                         │
│   [🚐 Linea 101][🚌 Micro A][🚐 204]   │  ← lista horizontal de rutas (chips)
│                                         │
├─────────────────────────────────────────┤
│ Linea 101 Ceja a Villa Adela [Minibus🔵]│
│ [⏱ 18 min]  Bs 2.0  06:00-22:00       │
│ ⚠ Hoy: feria, llega hasta Ballivian     │  ← nota feria (solo si isModified)
│ [● Recorrido][● Bus][Detalle]           │
└─────────────────────────────────────────┘
```

### 2.3 Implementación

#### 2.3.1 Ocultar botón "Agregar ruta" en AppBar

**Buscar en `_MapPageState.build()`:**

```dart
// ANTES:
appBar: AppBar(
  title: const Text('Mapa de transportes'),
  actions: [
    IconButton(
      tooltip: 'Agregar ruta',
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddRoutePage()));
        await _loadMapData();
      },
      icon: PhosphorIcon(PhosphorIcons.mapPin()),
    ),
  ],
),
```

```dart
// DESPUÉS:
final settings = AppSettingsScope.of(context);
// ...
appBar: AppBar(
  title: const Text('Mapa de transportes'),
  actions: [
    if (settings.isCollectorMode)
      IconButton(
        tooltip: 'Agregar ruta',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddRoutePage()));
          await _loadMapData();
        },
        icon: PhosphorIcon(PhosphorIcons.mapPin()),
      ),
  ],
),
```

Import a agregar al inicio del archivo:
```dart
import '../../../app/ruta_facil_app.dart';
```

#### 2.3.2 Color de polilínea por tipo de transporte

**Buscar en `_MapPageState.build()`:**

```dart
// ANTES:
PolylineLayer(
  polylines: [
    Polyline(
      points: activeInfo?.activePath ?? selectedRoute.path,
      color: Colors.blue,  // ← hardcoded
      strokeWidth: 5,
    ),
  ],
),
```

```dart
// DESPUÉS:
PolylineLayer(
  polylines: [
    Polyline(
      points: activeInfo?.activePath ?? selectedRoute.path,
      color: _colorFor(selectedRoute.transportType),  // ← dinámico
      strokeWidth: 5,
    ),
  ],
),
```

Agregar método helper en `_MapPageState` (si no existe):

```dart
Color _colorFor(TransportType type) {
  return switch (type) {
    TransportType.minibus => AppTheme.minibus,
    TransportType.trufi   => AppTheme.trufi,
    TransportType.micro   => AppTheme.micro,
  };
}
```

#### 2.3.3 Visualización del recorrido (actualizado 2026-06-10)

> **Reemplaza el diseño original de "stop markers".** Los puntos del path son
> muestras GPS (cientos por ruta), no paradas; dibujar un marcador por punto
> producía una nube ilegible al alejar el zoom. El diseño real es: línea con
> casing blanco + marcador de salida + pin de llegada, sin puntos intermedios.

**Implementado en `passenger_map_page.dart`, dentro del bloque `if (selectedRoute != null && selectedPath.isNotEmpty)`:**

```dart
PolylineLayer(
  polylines: [
    // Casing: borde blanco bajo la linea de color para resaltar sobre el mapa
    Polyline(points: selectedPath, color: Colors.white, strokeWidth: 9),
    Polyline(
      points: selectedPath,
      color: _colorFor(selectedRoute.transportType),
      strokeWidth: 5,
    ),
  ],
),
MarkerLayer(
  markers: [
    // Salida: circulo blanco con borde del color del transporte
    Marker(
      point: selectedPath.first,
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _colorFor(selectedRoute.transportType),
            width: 4,
          ),
        ),
      ),
    ),
    // Llegada: pin tipo gota con bandera a cuadros
    Marker(
      point: selectedPath.last,
      width: 40,
      height: 40,
      alignment: Alignment.topCenter,
      child: BusMarker(
        size: 40,
        icon: PhosphorIcons.flagCheckered(PhosphorIconsStyle.fill),
        color: _colorFor(selectedRoute.transportType),
      ),
    ),
  ],
),
// Buses: pin tipo gota compartido (widgets/bus_marker.dart)
MarkerLayer(
  markers: [
    for (final bus in buses)
      Marker(
        point: bus.location,
        width: 48,
        height: 48,
        alignment: Alignment.topCenter,
        child: BusMarker(
          size: 48,
          icon: _iconFor(selectedRoute.transportType, PhosphorIconsStyle.fill),
          color: _deviationDetector.isOutsideRoute(bus.location, selectedRoute)
              ? Colors.red
              : Colors.green,
        ),
      ),
  ],
),
```

#### 2.3.4 Layout del mapa — controles y selector de ruta

Reorganizar el `Column` principal del body. La estructura actual tiene los controles como bloque fijo encima del mapa. El objetivo es:

1. Chips de filtro en una fila delgada sobre el mapa
2. Mapa expandido con `Flexible` para tomar el máximo espacio
3. Lista horizontal de rutas como chips desplazables DEBAJO del mapa (reemplaza el dropdown)
4. `_MapSummary` o `_EmptyMapSummary` como antes

```dart
// ESTRUCTURA NUEVA del body (modo pasajero):
body: _isLoading
    ? const Center(child: CircularProgressIndicator())
    : Column(
        children: [
          // 1. Chips de filtro — fila delgada
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                _FilterChip(label: 'Todos', selected: _selectedTransportType == null,
                    onTap: () => _selectTransportType(null)),
                for (final type in TransportType.values)
                  _FilterChip(
                    label: type.label,
                    icon: _iconFor(type),
                    selected: _selectedTransportType == type,
                    onTap: () => _selectTransportType(type),
                  ),
              ],
            ),
          ),
          // 2. Mapa — ocupa el espacio disponible
          Flexible(
            flex: 3,
            child: FlutterMap( /* ... mismo código de mapa ... */ ),
          ),
          // 3. Lista horizontal de rutas (reemplaza dropdown)
          if (visibleRoutes.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: visibleRoutes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final route = visibleRoutes[index];
                  final isSelected = route.id == selectedRoute?.id;
                  return ActionChip(
                    avatar: Icon(_iconFor(route.transportType), size: 14),
                    label: Text(route.name, overflow: TextOverflow.ellipsis),
                    backgroundColor: isSelected
                        ? _colorFor(route.transportType).withValues(alpha: 0.2)
                        : null,
                    side: isSelected
                        ? BorderSide(color: _colorFor(route.transportType))
                        : null,
                    onPressed: () => _selectRoute(route.id),
                  );
                },
              ),
            ),
          // 4. Summary panel
          selectedRoute == null
              ? _EmptyMapSummary(routes: visibleRoutes)
              : _MapSummary( /* ... */ ),
        ],
      ),
```

Para modo colector (`isCollectorMode == true`), mantener el layout actual con el panel de controles completo y el dropdown.

#### 2.3.5 `_MapSummary` — datos orientados al pasajero

**Reemplazar el `_MapSummary` para que sea condicional por modo:**

```dart
// En _MapPageState.build(), pasar isCollectorMode:
_MapSummary(
  route: selectedRoute,
  buses: _buses,
  eta: _etaService.estimateArrival(selectedRoute),
  activeInfo: activeInfo,
  isCollectorMode: settings.isCollectorMode,
  onOpenDetail: () { /* ... */ },
),
```

**Actualizar la clase `_MapSummary` para aceptar `isCollectorMode`:**

```dart
class _MapSummary extends StatelessWidget {
  const _MapSummary({
    required this.route,
    required this.buses,
    required this.eta,
    required this.activeInfo,
    required this.isCollectorMode,  // ← nuevo parámetro
    required this.onOpenDetail,
  });

  final bool isCollectorMode;
  // ... resto igual

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(route.transportType);

    return Material(
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(route.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(
                  avatar: PhosphorIcon(PhosphorIcons.clock(), color: color, size: 16),
                  label: Text('${eta.inMinutes} min'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Chip de tipo + tarifa + horario (siempre visible)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(route.transportType.label)),
                Chip(label: Text('Bs ${(activeInfo?.fareBs ?? route.fareBs).toStringAsFixed(1)}')),
                Chip(label: Text(route.serviceHours)),
              ],
            ),
            // Nota de feria — solo si hay desvío activo
            if (activeInfo?.isModified == true) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.micro.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.micro.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(PhosphorIcons.warning(), color: AppTheme.micro, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(activeInfo!.note,
                          style: TextStyle(color: AppTheme.micro)),
                    ),
                  ],
                ),
              ),
            ],
            // Datos de colector — solo si isCollectorMode == true
            if (isCollectorMode) ...[
              if (route.recordedStartedAt != null) ...[
                const SizedBox(height: 6),
                Text('Grabada: ${_formatDateTime(route.recordedStartedAt!)}'),
              ],
              if (route.variationReason.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Causa: ${route.variationReason}'),
              ],
            ],
            const SizedBox(height: 10),
            // Leyenda + botón detalle
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _LegendItem(color: _colorFor(route.transportType), label: 'Recorrido'),
                const _LegendItem(color: Colors.green, label: 'Bus activo'),
                TextButton.icon(
                  onPressed: onOpenDetail,
                  icon: PhosphorIcon(PhosphorIcons.info()),
                  label: const Text('Detalle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 3. RouteDetailPage — rediseño para pasajero

### 3.1 Diseño objetivo

```
OBJETIVO (isCollectorMode == false):
┌─────────────────────────────────────────┐
│ Card principal                          │
│ 🚐 Linea 101 - Ceja a Villa Adela       │
│ Ceja El Alto → Villa Adela             │
│ [Minibus] [Linea 101] [Sindicato 16 Jul]│
│                                         │
│ ⚠ BANNER ÁMBAR (solo si feria activa)  │
│ "Hoy llega hasta Plaza Ballivian"       │
│                                         │
│ Bs 2.0    06:00 - 22:00   18 min       │
│ (tarifa base = activa, una sola vez)    │
│                                         │
│ Ruta no verificada                      │
│ Descripción de la ruta...               │
├─────────────────────────────────────────┤
│ Card tarifas por tramo (si fareRules)  │
├─────────────────────────────────────────┤
│ Card paradas principales               │
├─────────────────────────────────────────┤
│ [          Ver mapa          ]          │  ← FilledButton ancho completo
│ [🔖 Favorito]                          │  ← IconButton.filledTonal
│ [⚠ Reportar cambio o problema]         │  ← OutlinedButton
│                                         │
│ (sin Exportar, sin Borrar para pasajero)│
└─────────────────────────────────────────┘

COLECTOR (isCollectorMode == true) — igual que hoy, sin cambios.
```

### 3.2 Implementación

**En `_RouteDetailPageState.build()`**, agregar lectura de settings:

```dart
@override
Widget build(BuildContext context) {
  final route = widget.route;
  final eta = _etaService.estimateArrival(route);
  final activeInfo = _availabilityService.evaluate(route, DateTime.now());
  final settings = AppSettingsScope.of(context);   // ← AGREGAR
  final isPassenger = !settings.isCollectorMode;   // ← helper local
```

Import si no existe:
```dart
import '../../../app/ruta_facil_app.dart';
```

**Dentro de la Card principal, ocultar campos de colector:**

```dart
// OCULTAR cuando isPassenger:
if (!isPassenger && route.recordedStartedAt != null)
  Text('Grabacion: ${_formatDateTime(route.recordedStartedAt!)}'),
if (!isPassenger && route.recordedEndedAt != null)
  Text('Fin: ${_formatDateTime(route.recordedEndedAt!)}'),
if (!isPassenger && route.variationReason.isNotEmpty)
  Text('Causa observada: ${route.variationReason}'),
```

**Mostrar tarifa una sola vez para pasajero:**

```dart
// ANTES (dos filas):
Text('Tarifa: Bs ${route.fareBs.toStringAsFixed(1)}'),
Text('Tarifa actual: Bs ${activeInfo.fareBs.toStringAsFixed(1)}'),

// DESPUÉS:
if (isPassenger) ...[
  // Una sola tarifa — la activa
  Text('Tarifa: Bs ${activeInfo.fareBs.toStringAsFixed(1)}'),
  // Solo mostrar diferencia si cambia
  if (activeInfo.fareBs != route.fareBs)
    Text(
      'Tarifa normal: Bs ${route.fareBs.toStringAsFixed(1)}',
      style: Theme.of(context).textTheme.bodySmall,
    ),
] else ...[
  // Colector ve ambas (comportamiento actual)
  Text('Tarifa: Bs ${route.fareBs.toStringAsFixed(1)}'),
  Text('Tarifa actual: Bs ${activeInfo.fareBs.toStringAsFixed(1)}'),
],
```

**Banner de desvío de feria (nuevo widget):**

Insertar DESPUÉS de los chips de tipo/línea/sindicato y ANTES de los datos de tarifa:

```dart
// Banner de feria — solo para pasajero cuando hay desvío activo
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
            style: TextStyle(
              color: AppTheme.micro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  ),
],
```

**Jerarquía de botones — condicional por modo:**

```dart
// Reemplazar el bloque de botones actual:
const SizedBox(height: 12),
Row(
  children: [
    Expanded(
      child: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MapPage(initialRouteId: route.id)),
        ),
        icon: PhosphorIcon(PhosphorIcons.mapTrifold()),
        label: const Text('Ver mapa'),
      ),
    ),
    const SizedBox(width: 12),
    IconButton.filledTonal(
      tooltip: _isSaved ? 'Quitar guardado' : 'Guardar ruta',
      onPressed: _toggleSaved,
      icon: PhosphorIcon(_isSaved
          ? PhosphorIcons.bookmark(PhosphorIconsStyle.fill)
          : PhosphorIcons.bookmark()),
    ),
  ],
),
const SizedBox(height: 12),
OutlinedButton.icon(
  onPressed: _showReportDialog,
  icon: PhosphorIcon(PhosphorIcons.warning()),
  label: const Text('Reportar cambio o problema'),
),
// Solo para colector:
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
```

---

## 4. SearchDestinationPage — ListTile mejorado

### 4.1 Diseño objetivo

```
ACTUAL:
┌──────────────────────────────────────────────┐
│ 🚐  Linea 101 - Ceja a Villa Adela           │
│     Minibus 101 - Ceja -> Cruce -> Julio...  │  ← demasiadas paradas
└──────────────────────────────────────────────┘

OBJETIVO (isCollectorMode == false):
┌──────────────────────────────────────────────┐
│ ┌──┐  Linea 101 - Ceja a Villa Adela    Bs2.0│
│ │🚐│  Ceja El Alto → Villa Adela         chip│
│ └──┘                                         │
└──────────────────────────────────────────────┘
```

### 4.2 Implementación

En el `ListView.builder` de `SearchDestinationPage.build()`, reemplazar el `ListTile` actual:

```dart
// ANTES:
return ListTile(
  leading: Icon(_iconFor(route.transportType)),
  title: Text(route.name),
  subtitle: Text(
    '${route.transportType.label} ${route.line} - '
    '${route.stops.join(' -> ')}',
  ),
  trailing: PhosphorIcon(PhosphorIcons.caretRight()),
  onTap: () async { /* ... */ },
);

// DESPUÉS:
final color = _colorFor(route.transportType);
return ListTile(
  leading: Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(_iconFor(route.transportType), color: color),
  ),
  title: Text(route.name),
  subtitle: Text('${route.origin} → ${route.destination}'),
  trailing: Chip(
    label: Text('Bs ${route.fareBs.toStringAsFixed(1)}'),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
  ),
  onTap: () async { /* ... sin cambios ... */ },
);
```

Agregar helper `_colorFor` en `_SearchDestinationPageState`:

```dart
Color _colorFor(TransportType type) {
  return switch (type) {
    TransportType.minibus => AppTheme.minibus,
    TransportType.trufi   => AppTheme.trufi,
    TransportType.micro   => AppTheme.micro,
  };
}
```

Import a agregar:
```dart
import '../../../app/app_theme.dart';
```

---

## 5. Wireframes completos por pantalla

### MapPage — pasajero (isCollectorMode = false)

```
┌─────────────────────────────────────────┐
│ ← Mapa de transportes                   │  ← sin botón Agregar ruta
├─────────────────────────────────────────┤
│ [Todos][🚐Minibus][🚕Trufi][🚌Micro]  →│  ← chips scroll horizontal
│                                          │
│  ┌────────────────────────────────────┐ │
│  │                                    │ │
│  │   [OSM tile layer]                 │ │
│  │                                    │ │
│  │    ○━━━━━━📍━━━━━━⚑  polilínea    │ │  ← color por tipo + casing blanco
│  │    ○ = salida  📍 = bus (pin gota) │ │
│  │    ⚑ = llegada (pin con bandera)   │ │
│  │                                    │ │
│  └────────────────────────────────────┘ │
│ [Línea 101][Trufi 42][Micro A][204] →   │  ← ActionChips horizontal
├─────────────────────────────────────────┤
│ Linea 101 - Ceja a Villa Adela  [18min] │
│ [Minibus] [Bs 2.0] [06:00-22:00]       │
│ ⚠ Hoy: llega solo hasta Ballivian      │  ← solo si feria
│ [● Recorrido][● Bus][Detalle]           │
└─────────────────────────────────────────┘
```

### RouteDetailPage — pasajero (isCollectorMode = false)

```
┌─────────────────────────────────────────┐
│ AppBar: Detalle de ruta                 │
├─────────────────────────────────────────┤
│ Card:                                   │
│  🚐  Linea 101 - Ceja a Villa Adela     │
│  Ceja El Alto → Villa Adela            │
│  [Minibus][Linea 101][Sindicato 16 Jul] │
│                                         │
│  ┌─── BANNER ÁMBAR (solo si feria) ───┐ │
│  │ ⚠ Hoy: llega hasta Plaza Ballivian │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Tarifa: Bs 2.0                         │
│  Horario: 06:00 - 22:00                 │
│  Tiempo estimado: 18 min                │
│  Ruta no verificada                     │
│  Descripción...                         │
│                                         │
│  (SIN fechas de grabación)              │
│  (SIN "Causa observada:")               │
├─────────────────────────────────────────┤
│ Card tarifas por tramo (si aplica)      │
├─────────────────────────────────────────┤
│ Card paradas principales                │
├─────────────────────────────────────────┤
│ [          Ver mapa          ]  [🔖]    │
│ [⚠ Reportar cambio o problema]         │
│                                         │
│ (SIN Exportar)                          │
│ (SIN Borrar ruta)                       │
└─────────────────────────────────────────┘
```

### SearchDestinationPage — resultado mejorado

```
┌─────────────────────────────────────────┐
│ [🔍 Estoy en...                       ] │
│ [🔍 Quiero ir a...                    ] │
│                                         │
│ [Todos][🚐Minibus][🚕Trufi][🚌Micro] → │
│                                         │
│ Resultados                              │
│ ┌─────────────────────────────────────┐ │
│ │ ┌──┐  Linea 101 - Ceja Villa Adela  │ │
│ │ │🚐│  Ceja El Alto → Villa Adela    │ │
│ │ └──┘                        [Bs 2.0]│ │
│ ├─────────────────────────────────────┤ │
│ │ ┌──┐  Trufi 42 - Ceja a Senkata    │ │
│ │ │🚕│  Ceja El Alto → Senkata       │ │
│ │ └──┘                        [Bs 2.5]│ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

---

## 6. Correctness Properties

### P1 — Botón Agregar ruta oculto
```
DADO isCollectorMode == false
ENTONCES AppBar de MapPage no contiene IconButton con tooltip "Agregar ruta"
```

### P2 — Color de polilínea
```
DADO ruta seleccionada con transportType = minibus
ENTONCES Polyline.color == AppTheme.minibus (#22577A)

DADO ruta seleccionada con transportType = trufi
ENTONCES Polyline.color == AppTheme.trufi (#2D936C)
```

### P3 — Summary solo datos pasajero
```
DADO isCollectorMode == false Y ruta seleccionada
ENTONCES _MapSummary no contiene texto con formato "Grabada: dd/mm/yyyy"
ENTONCES _MapSummary no contiene texto "Causa:"
```

### P4 — Botones en RouteDetailPage
```
DADO isCollectorMode == false
ENTONCES find('Borrar ruta').isEmpty
ENTONCES find('Exportar o compartir ruta').isEmpty
ENTONCES find('Ver mapa').isNotEmpty
ENTONCES find('Reportar cambio o problema').isNotEmpty
```

### P5 — Subtitle en resultados de búsqueda
```
DADO ruta con origin='Ceja El Alto', destination='Villa Adela', stops=['Ceja','Cruce Viacha','16 de Julio','Villa Adela']
ENTONCES ListTile.subtitle == 'Ceja El Alto → Villa Adela'
ENTONCES ListTile.subtitle NO contiene 'Cruce Viacha'
```
