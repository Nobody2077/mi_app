# Ruta Facil El Alto - Propuesta funcional

Documento base: `mineria de datos (2).pdf`.

## Objetivo de la app

Desarrollar una aplicacion movil colaborativa para visualizar rutas del transporte
urbano de El Alto, estimar tiempos de llegada y recolectar datos GPS de usuarios
que viajan en minibuses, trufis o micros.

## Estructura tecnica sugerida

- `lib/app`: configuracion global de la aplicacion, tema y punto de entrada visual.
- `lib/core`: constantes y utilidades compartidas.
- `lib/features/auth`: inicio de sesion.
- `lib/features/home`: menu principal.
- `lib/features/routes`: rutas, busqueda, mapa, modelos y servicios de calculo.
- `lib/features/share_location`: flujo para compartir ubicacion colaborativa.
- `docs`: notas tecnicas, alcance y propuesta del proyecto.
- `test`: pruebas automatizadas.

## Funcionalidades minimas del prototipo

- Login basico para entrar al sistema.
- Menu con acceso a busqueda, rutas, mapa y colaboracion GPS.
- Lista de rutas digitalizadas.
- Busqueda por destino, parada, zona, linea, sindicato o tipo de transporte.
- Mapa con OpenStreetMap.
- Estimacion de llegada basada en distancia y velocidad promedio.
- Simulacion de ubicacion de buses.
- Pantalla para activar/desactivar envio colaborativo de ubicacion.
- Deteccion inicial de desvio comparando posicion con puntos de la ruta.
- Intento de ajuste de ruta a calles reales usando OSRM cuando hay internet.

## Correcciones obligatorias

- Separar el codigo que estaba concentrado en `main.dart`.
- Corregir textos con problemas de codificacion.
- Reemplazar el test de contador generado por Flutter.
- Evitar credenciales quemadas en produccion; el login actual es solo demo.
- Agregar permisos reales de ubicacion antes de usar GPS en Android/iOS.
- Preparar una fuente de datos real o simulada documentada para las pruebas.

## Funcionalidades que conviene agregar despues

- Registro de usuarios y roles: pasajero, administrador y recolector de rutas.
- Permisos GPS usando una libreria como `geolocator`.
- Backend con API REST para guardar rutas, paradas y reportes.
- Base de datos PostgreSQL con PostGIS para calculos geoespaciales.
- Panel administrativo para digitalizar rutas desde el mapa.
- Historial de posiciones para analisis de trayectorias.
- Prediccion de tiempos con datos historicos.
- Clustering de zonas con alta demanda usando Python, Pandas y Scikit-learn.
- Evaluacion de precision: error medio de tiempo estimado, tiempo de respuesta y aceptacion de usuarios.

## Dataset inicial recomendado

- `routes`: id, nombre, origen, destino, velocidad promedio.
- `stops`: id, nombre, latitud, longitud.
- `route_points`: route_id, orden, latitud, longitud.
- `bus_positions`: bus_id, route_id, latitud, longitud, fecha_hora.
- `user_reports`: usuario, tipo_reporte, ruta, comentario, fecha_hora.

## Como agregar una ruta manual

Para que una ruta se vea como Google Maps no basta con dos puntos. Se necesitan
puntos de control: casa, esquinas importantes, avenidas por donde pasa el
transporte, paradas y destino final.

En el prototipo, estos datos estan en:

`lib/features/routes/data/mock_route_repository.dart`

Cada ruta tiene:

- `transportType`: `minibus`, `trufi` o `micro`.
- `syndicate`: nombre del sindicato o cooperativa.
- `line`: numero, letra o nombre de linea.
- `origin` y `destination`: inicio y fin visibles para el usuario.
- `fareBs`: tarifa aproximada.
- `serviceHours`: horario de servicio.
- `stops`: paradas principales.
- `path`: coordenadas manuales por donde debe pasar la ruta.

OSRM intenta convertir esos puntos en una linea sobre calles reales. Si no hay
internet o si faltan puntos, se muestra la linea manual.

### Pasos practicos para levantar una ruta real

1. Elige una ruta pequena para comenzar, por ejemplo casa a universidad.
2. Anota el tipo de transporte: minibus, trufi o micro.
3. Anota el sindicato, numero/letra de linea, tarifa y horario aproximado.
4. Recorre la ruta y registra puntos clave:
   - punto donde subes
   - esquinas donde gira
   - avenidas principales
   - paradas conocidas
   - punto donde bajas
5. Obtiene coordenadas de cada punto desde Google Maps u OpenStreetMap:
   - clic derecho en el lugar
   - copiar latitud y longitud
6. Agrega esos puntos en `path` como `LatLng(latitud, longitud)`.
7. Agrega nombres simples en `stops` para que el usuario entienda el recorrido.
8. Ejecuta la app y revisa si OSRM la ajusta bien a las calles.

Si la ruta se desvia, agrega mas puntos de control antes y despues del giro
incorrecto. Esa es la forma mas rapida de corregir recorridos manuales.
