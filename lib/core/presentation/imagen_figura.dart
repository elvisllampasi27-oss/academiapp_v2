import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Figura de una pregunta o solución. La usan los exámenes y las prácticas.
/// Nunca ocupa más del 40 % del alto de la pantalla (máx. 320 px); al
/// tocarla se abre en grande y se puede ampliar con los dedos.
class ImagenFigura extends StatelessWidget {
  final String url;

  const ImagenFigura(this.url, {super.key});

  @override
  Widget build(BuildContext context) {
    final alto = (MediaQuery.sizeOf(context).height * 0.4)
        .clamp(160.0, 320.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alto),
          child: Semantics(
            button: true,
            label: 'Ampliar figura',
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => _FiguraAmpliada(url: url),
                ),
              ),
              child: Stack(
                children: [
                  _Figura(url: url),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.zoom_in,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Figura extends StatelessWidget {
  final String url;

  const _Figura({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
                  width: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (context, error, pila) => Container(
            height: 80,
            width: 260,
            color: ColoresApp.panel,
            alignment: Alignment.center,
            child: const Text(
              'No se pudo cargar la figura.',
              style: TextStyle(color: ColoresApp.apagado),
            ),
          ),
        ),
      ),
    );
  }
}

/// La figura a pantalla completa: se amplía con los dedos (hasta 5x).
class _FiguraAmpliada extends StatelessWidget {
  final String url;

  const _FiguraAmpliada({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Figura'),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _Figura(url: url),
          ),
        ),
      ),
    );
  }
}
