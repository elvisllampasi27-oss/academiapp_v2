import 'package:flutter/material.dart';

import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/colores_app.dart';
import '../domain/clase_docente.dart';

/// Corazones de las clases de un tema: cuántos tiene cada una y a cuáles
/// les dio el alumno (uno por alumno). Cambia al instante y, si no se
/// pudo guardar, vuelve como estaba.
class CorazonesClases extends ChangeNotifier {
  final RepositorioClasesDocente repositorio;
  final String uid;
  final Map<String, int> _cantidad;
  final Set<String> _mios;
  final _enviando = <String>{};

  CorazonesClases({
    required this.repositorio,
    required this.uid,
    required List<ClaseDocente> clases,
    Set<String> mios = const {},
  }) : _cantidad = {for (final c in clases) c.id: c.corazones},
       _mios = {...mios};

  int cantidad(String claseId) => _cantidad[claseId] ?? 0;

  bool dado(String claseId) => _mios.contains(claseId);

  /// false si no se pudo guardar.
  Future<bool> alternar(String claseId) async {
    if (!_enviando.add(claseId)) return true;
    final dar = !dado(claseId);
    _aplicar(claseId, dar);
    try {
      if (dar) {
        await repositorio.darCorazon(claseId, uid);
      } else {
        await repositorio.quitarCorazon(claseId, uid);
      }
      return true;
    } catch (_) {
      _aplicar(claseId, !dar);
      return false;
    } finally {
      _enviando.remove(claseId);
    }
  }

  void _aplicar(String claseId, bool dar) {
    if (dar) {
      _mios.add(claseId);
    } else {
      _mios.remove(claseId);
    }
    final n = cantidad(claseId) + (dar ? 1 : -1);
    _cantidad[claseId] = n < 0 ? 0 : n;
    notifyListeners();
  }
}

const colorCorazon = Color(0xFFFF5C7A);

/// "1.2 mil" en vez de 1234.
String cantidadCorta(int n) {
  if (n < 1000) return '$n';
  final mil = n / 1000;
  final texto = mil >= 10 ? mil.toStringAsFixed(0) : mil.toStringAsFixed(1);
  return '${texto.replaceAll('.0', '')} mil';
}

/// Corazón con su cantidad. Al darlo "salta" como en TikTok.
class BotonCorazon extends StatefulWidget {
  final bool dado;
  final int cantidad;
  final VoidCallback onTap;
  final double tamano;

  const BotonCorazon({
    super.key,
    required this.dado,
    required this.cantidad,
    required this.onTap,
    this.tamano = 26,
  });

  @override
  State<BotonCorazon> createState() => _BotonCorazonState();
}

class _BotonCorazonState extends State<BotonCorazon>
    with SingleTickerProviderStateMixin {
  late final _salto = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  static final _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.45), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.45, end: 0.88), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.88, end: 1), weight: 35),
  ]);

  @override
  void didUpdateWidget(BotonCorazon anterior) {
    super.didUpdateWidget(anterior);
    if (widget.dado && !anterior.dado && !sinAnimaciones(context)) {
      _salto.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _salto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dado = widget.dado;
    return Semantics(
      button: true,
      label: dado ? 'Quitar corazón' : 'Dar corazón',
      child: InkResponse(
        onTap: widget.onTap,
        radius: widget.tamano,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _escala.animate(
                  CurvedAnimation(parent: _salto, curve: Curves.easeOut),
                ),
                child: Icon(
                  dado ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: widget.tamano,
                  color: dado ? colorCorazon : ColoresApp.apagado,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cantidadCorta(widget.cantidad),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dado ? colorCorazon : ColoresApp.apagado,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
