# Documento de Requisitos — Rediseño de UI para Pasajeros

## Introducción

La aplicación **Ruta Fácil El Alto** sirve a dos tipos de usuarios: colectores (que graban rutas GPS) y pasajeros (que buscan y consultan rutas). Actualmente las pantallas `MapPage`, `RouteDetailPage` y `SearchDestinationPage` mezclan datos e interacciones de ambos perfiles, lo que genera una experiencia confusa y poco útil para los pasajeros.

Este rediseño separa visualmente ambos perfiles usando la bandera `isCollectorMode` ya existente en `AppSettingsScope`, sin alterar ninguna lógica de grabación ni las páginas exclusivas del colector (`AddRoutePage`, `RoutesPage`). El objetivo es que, en modo pasajero, las tres pantallas afectadas muestren solo información relevante para viajar: tarifa, horario, tiempo estimado de llegada (ETA) y disponibilidad de la ruta.

> **Nota de implementación (2026-06-10):** El mapa del pasajero se implementó
> como página dedicada `PassengerMapPage`
> (`lib/features/routes/presentation/passenger_map_page.dart`) en lugar de
> condicionar `MapPage` por `isCollectorMode`. `MapPage` quedó como el mapa
> del colector. Las referencias a "`MapPage` en modo pasajero" de este
> documento deben leerse como `PassengerMapPage`. Además, ambos mapas
> comparten el widget `BusMarker` (pin tipo gota) para los buses.

---

## Glosario

- **Pasajero**: Usuario de la app con `isCollectorMode == false`. Consulta rutas para viajar.
- **Colector**: Usuario de la app con `isCollectorMode == true`. Graba rutas GPS. Su UI no se modifica.
- **MapPage**: Pantalla principal del mapa con filtros de tipo de transporte y selección de ruta.
- **RouteDetailPage**: Pantalla con el detalle completo de una ruta seleccionada.
- **SearchDestinationPage**: Pantalla de búsqueda de rutas por origen y destino.
- **AppSettingsScope**: `InheritedNotifier` que expone `isCollectorMode` en toda la aplicación.
- **AppTheme**: Clase con los colores oficiales por tipo de transporte (`minibus`, `trufi`, `micro`).
- **ETA**: Tiempo Estimado de Llegada, calculado por `EtaService.estimateArrival`.
- **RouteAvailabilityInfo**: Resultado de `RouteAvailabilityService.evaluate`; contiene `fareBs`, `activePath`, `isModified` y `note`.
- **Panel de resumen (`_MapSummary`)**: Widget en la parte inferior de `MapPage` que muestra información de la ruta seleccionada.
- **Desvío de feria**: Modificación de recorrido aplicable en días de feria, representada por `RouteAvailabilityInfo.isModified == true`.
- **Banner de desvío**: Componente visual destacado (color ámbar/naranja) que alerta al pasajero sobre un desvío activo.
- **Chip de tarifa**: Elemento visual `Chip` que muestra el precio en bolivianos (`Bs X.X`).
- **Parada**: Elemento de `TransitRoute.stops`; punto intermedio entre origen y destino.

---

## Requisitos

---

### Requisito 1: Ocultar el botón "Agregar ruta" en modo pasajero

**Historia de usuario:** Como pasajero, quiero que la pantalla del mapa no muestre acciones que no me corresponden, para no confundirme con funciones de grabación.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false`, EL `MapPage` NO DEBE mostrar el `IconButton` de "Agregar ruta" en el `AppBar`.
2. CUANDO `isCollectorMode == true`, EL `MapPage` DEBE mostrar el `IconButton` de "Agregar ruta" en el `AppBar` con el comportamiento actual.
3. EL `MapPage` DEBE leer el valor de `isCollectorMode` desde `AppSettingsScope.of(context)` sin modificar la clase `AppSettings`.

---

### Requisito 2: Mapa ampliado — controles superpuestos o colapsables

**Historia de usuario:** Como pasajero, quiero que el mapa ocupe la mayor parte de la pantalla, para tener una visión clara del recorrido sin que los controles lo reduzcan.

#### Criterios de aceptación

1. MIENTRAS `isCollectorMode == false` Y una ruta está seleccionada, EL `MapPage` DEBE mostrar el mapa en al menos el 65 % de la altura disponible de la pantalla.
2. CUANDO `isCollectorMode == false`, LOS filtros de tipo de transporte y el selector de ruta en `MapPage` DEBEN presentarse de forma que no reduzcan la altura del mapa a un bloque fijo de controles por encima del mismo.
3. CUANDO `isCollectorMode == true`, EL `MapPage` DEBE mantener el diseño de controles actual sin cambios.

---

### Requisito 3: Selector de ruta táctil en modo pasajero

**Historia de usuario:** Como pasajero, quiero seleccionar una ruta de forma cómoda en pantalla táctil con nombres largos, para no tener que usar un desplegable estrecho.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false`, EL `MapPage` DEBE reemplazar el `DropdownButtonFormField` de selección de ruta por un componente táctil alternativo (hoja inferior o lista de rutas desplazable horizontalmente).
2. EL componente de selección de ruta DEBE mostrar el nombre completo de cada ruta sin truncar el texto de forma ilegible.
3. CUANDO el pasajero selecciona una ruta en el componente alternativo, EL `MapPage` DEBE actualizar el mapa con el recorrido y el panel de resumen de esa ruta, con el mismo comportamiento que la selección actual.
4. CUANDO `isCollectorMode == true`, EL `MapPage` DEBE conservar el `DropdownButtonFormField` existente sin cambios.

---

### Requisito 4: Panel de resumen orientado al pasajero (`_MapSummary`)

**Historia de usuario:** Como pasajero, quiero ver en el panel inferior del mapa solo información útil para mi viaje, sin datos de grabación que no entiendo.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false` Y una ruta está seleccionada, EL `_MapSummary` DEBE mostrar: nombre de la ruta, chip del tipo de transporte, chip de ETA en minutos, tarifa activa en bolivianos (`activeInfo.fareBs`) y horario de servicio (`route.serviceHours`).
2. CUANDO `isCollectorMode == false`, EL `_MapSummary` NO DEBE mostrar los campos `recordedStartedAt`, `recordedEndedAt` ni `variationReason`.
3. CUANDO `isCollectorMode == false` Y `RouteAvailabilityInfo.isModified == true`, EL `_MapSummary` DEBE mostrar el texto de `activeInfo.note` junto a la tarifa activa.
4. CUANDO `isCollectorMode == true`, EL `_MapSummary` DEBE mantener su comportamiento y contenido actuales sin cambios.

---

### Requisito 5: Color de polilínea por tipo de transporte

**Historia de usuario:** Como pasajero, quiero que el recorrido en el mapa tenga el color del tipo de transporte, para identificar visualmente de qué línea se trata.

#### Criterios de aceptación

1. CUANDO se dibuja la polilínea del recorrido de una ruta en `MapPage`, EL `MapPage` DEBE usar el color correspondiente al tipo de transporte: `AppTheme.minibus` (`#22577A`) para minibus, `AppTheme.trufi` (`#2D936C`) para trufi y `AppTheme.micro` (`#E89A00`) para micro.
2. EL `MapPage` DEBE obtener el color de `AppTheme` y no definir colores de polilínea de forma literal en el código.

---

### Requisito 6: Visualización del recorrido en el mapa

> **Actualizado el 2026-06-10 — reemplaza al requisito original.** La versión
> anterior pedía "un marcador visual en cada punto de `activePath`", partiendo
> del supuesto de que esos puntos eran paradas. Era un supuesto equivocado:
> los puntos del path son muestras GPS grabadas en campo (cientos por ruta),
> no paradas, y al alejar el zoom formaban una nube de puntos ilegible. Las
> paradas reales (`TransitRoute.stops`) son solo nombres sin coordenadas, por
> lo que no pueden marcarse en el mapa con los datos actuales.

**Historia de usuario:** Como pasajero, quiero ver el recorrido como una línea clara con su inicio y fin marcados, para entender el trayecto de un vistazo a cualquier nivel de zoom.

#### Criterios de aceptación

1. CUANDO una ruta está seleccionada, EL mapa de pasajero DEBE dibujar el recorrido como polilínea doble: una línea blanca de 9 px debajo (casing) y encima la línea de 5 px del color del tipo de transporte.
2. EL mapa DEBE mostrar un único marcador de salida (círculo blanco con borde del color del transporte) en el primer punto del path, y un único marcador de llegada (pin tipo gota con bandera a cuadros, en el color del transporte) en el último punto.
3. EL mapa NO DEBE dibujar marcadores en los puntos intermedios del path.
4. LOS buses DEBEN mostrarse con el pin tipo gota compartido (`BusMarker`, en `presentation/widgets/bus_marker.dart`) con el ícono del tipo de transporte, visualmente distinguible del marcador de llegada (que usa bandera).

---

### Requisito 7: Vista de detalle de ruta orientada al pasajero

**Historia de usuario:** Como pasajero, quiero ver en el detalle de la ruta únicamente la información que me ayuda a viajar, sin fechas ni datos de grabación.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` NO DEBE mostrar los campos `recordedStartedAt`, `recordedEndedAt` ni el texto literal de `variationReason`.
2. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` DEBE mostrar la tarifa una sola vez usando `activeInfo.fareBs`.
3. CUANDO `isCollectorMode == false` Y `route.fareBs != activeInfo.fareBs`, EL `RouteDetailPage` DEBE mostrar una nota indicando que la tarifa activa difiere de la base, junto al valor de ambas.
4. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` DEBE mantener: nombre, chips de tipo de transporte y línea, trayecto `origin → destination`, lista de paradas, tabla de tarifas por tramo (`fareRules`) y descripción.
5. CUANDO `isCollectorMode == true`, EL `RouteDetailPage` DEBE mantener su contenido y comportamiento actuales sin cambios.

---

### Requisito 8: Banner de desvío de feria en detalle de ruta

**Historia de usuario:** Como pasajero, quiero que me avisen de forma destacada cuando hoy hay un desvío de feria activo, para no tomar la ruta equivocada.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false` Y `RouteAvailabilityInfo.isModified == true`, EL `RouteDetailPage` DEBE mostrar un banner de color ámbar/naranja con el texto de `activeInfo.note` en la parte superior del contenido de la tarjeta principal.
2. CUANDO `isCollectorMode == false` Y `RouteAvailabilityInfo.isModified == false`, EL `RouteDetailPage` NO DEBE mostrar el banner de desvío.

---

### Requisito 9: Jerarquía visual de acciones en detalle de ruta para pasajeros

**Historia de usuario:** Como pasajero, quiero que la acción principal ("Ver mapa") sea visualmente prominente y las secundarias estén diferenciadas, para orientarme rápido en la pantalla.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` DEBE presentar el botón "Ver mapa" como `FilledButton` de ancho completo como acción primaria.
2. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` DEBE presentar el botón de favoritos (`IconButton.filledTonal`) y el botón "Reportar cambio o problema" (`OutlinedButton`) como acciones secundarias.
3. CUANDO `isCollectorMode == false`, EL `RouteDetailPage` NO DEBE mostrar el botón "Borrar ruta" ni el botón "Exportar o compartir ruta".
4. CUANDO `isCollectorMode == true`, EL `RouteDetailPage` DEBE mantener todos los botones actuales con su estilo y comportamiento sin cambios.

---

### Requisito 10: Ítem de resultado de búsqueda mejorado

**Historia de usuario:** Como pasajero, quiero que cada resultado de búsqueda de ruta muestre el color del transporte, el nombre, el trayecto resumido y la tarifa, para elegir la opción más conveniente sin tener que entrar al detalle.

#### Criterios de aceptación

1. CUANDO `isCollectorMode == false` Y se muestran resultados en `SearchDestinationPage`, CADA `ListTile` DEBE tener: un `leading` con ícono del tipo de transporte sobre fondo de color `AppTheme.<tipo>` al 15 % de opacidad, un `title` con el nombre de la ruta, un `subtitle` con `origin → destination` (solo los dos extremos de la ruta), y un `trailing` con un `Chip` mostrando `Bs X.X` con la tarifa base de la ruta.
2. EL `subtitle` del `ListTile` DEBE mostrar únicamente `route.origin → route.destination` y NO la cadena de todas las paradas intermedias (`stops.join(' -> ')`).
3. CUANDO `isCollectorMode == true`, EL `SearchDestinationPage` DEBE conservar el comportamiento y estilo de lista actuales sin cambios.

---

### Requisito 11: Conservar chips de filtro y comportamiento de autocompletado en búsqueda

**Historia de usuario:** Como pasajero, quiero que los filtros por tipo de transporte y el autocompletado sigan funcionando igual que antes, porque ya son útiles y cómodos.

#### Criterios de aceptación

1. EL `SearchDestinationPage` DEBE mantener los `ChoiceChip` de filtro por tipo de transporte (`Todos`, `Minibus`, `Trufi`, `Micro`) con el mismo comportamiento actual.
2. EL `SearchDestinationPage` DEBE mantener el comportamiento de autocompletado en los campos "Estoy en..." y "Quiero ir a..." con las mismas sugerencias basadas en `origin`, `destination` y `stops` de las rutas.
3. CUANDO se aplica un filtro de tipo de transporte, EL `SearchDestinationPage` DEBE actualizar tanto los resultados de la lista como las sugerencias del autocompletado para reflejar solo las rutas del tipo seleccionado.

---

### Requisito 12: Sin cambios en páginas del colector

**Historia de usuario:** Como colector, quiero que mis páginas de trabajo (`AddRoutePage`, `RoutesPage`) y la lógica de grabación no cambien, para seguir usando la app sin interrupciones.

#### Criterios de aceptación

1. EL `AddRoutePage` NO DEBE ser modificado por este rediseño.
2. EL `RoutesPage` NO DEBE ser modificado por este rediseño.
3. LAS clases `AppSettings`, `AppTheme` y los modelos del dominio (`TransitRoute`, `RouteScheduleRule`, `FareRule`, etc.) NO DEBEN ser modificados por este rediseño.
4. LA lógica de `isCollectorMode` existente en `HomePage` NO DEBE ser modificada por este rediseño.
