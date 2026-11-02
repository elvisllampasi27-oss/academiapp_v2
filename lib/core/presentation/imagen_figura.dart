import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Figura de una pregunta o solución (imagen publicada en Hosting). La usan
/// los exámenes y las prácticas.
class ImagenFigura extends StatelessWidget {
  final String url;

  const ImagenFigura(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          // Las figuras suelen ser escaneos con fondo blanco.
          color: Colors.white,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, hijo, progreso) => progreso == null
                ? hijo
                : const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (context, error, pila) => Container(
              height: 80,
              color: ColoresApp.panel,
              alignment: Alignment.center,
              child: const Text(
                'No se pudo cargar la figura.',
                style: TextStyle(color: ColoresApp.apagado),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
