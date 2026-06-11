import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pin tipo gota para marcar buses en el mapa.
///
/// La punta inferior señala el punto GPS, por lo que el `Marker` que lo
/// contenga debe usar `alignment: Alignment.topCenter` y el mismo
/// ancho/alto que [size].
class BusMarker extends StatelessWidget {
  const BusMarker({
    required this.icon,
    required this.color,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // El cuadrado rotado 45° ocupa size de diagonal; su lado es size/√2.
    final side = size / math.sqrt2;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(side / 2),
                topRight: Radius.circular(side / 2),
                bottomRight: Radius.circular(side / 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Icon(icon, color: Colors.white, size: side * 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
