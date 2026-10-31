import 'package:flutter/material.dart';

import '../../core/presentation/colores_app.dart';
import '../../core/presentation/formato_fecha.dart';
import '../../features/academic/domain/entities/contexto_dia_estudiante.dart';
import '../../features/academic/domain/entities/curso.dart';
import '../../features/academic/domain/entities/tema.dart';
import '../../features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../features/adaptive_engine/domain/entities/recomendacion.dart';

/// Inicio: lo primero que ve el estudiante es SU ruta de hoy
/// y lo que le conviene reforzar.
class InicioPage extends StatelessWidget {
  final String nombre;
  final DateTime hoy;
  final ContextoDiaEstudiante dia;
  final List<ItemMiRuta> ruta;
  final void Function(Tema tema, Curso? curso) onAbrirTema;
  final VoidCallback onVerRuta;
  final VoidCallback onAbrirPerfil;

  /// Cuántas recomendaciones de "Reforzar" se muestran en el inicio.
  final int maximoRefuerzos;

  const InicioPage({
    super.key,
    required this.nombre,
    required this.hoy,
    required this.dia,
    required this.ruta,
    required this.onAbrirTema,
    required this.onVerRuta,
    required this.onAbrirPerfil,
    this.maximoRefuerzos = 2,
  });

  Tema? _tema(String id) {
    for (final tema in dia.temas) {
      if (tema.id == id) return tema;
    }
    return null;
  }

  Curso? _curso(String? id) {
    for (final curso in dia.cursos) {
      if (curso.id == id) return curso;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final numeroDia = dia.dia?.numero;
    final encabezado = numeroDia == null
        ? fechaCorta(hoy)
        : '${fechaCorta(hoy)} · Día académico $numeroDia';
    final primerNombre = nombre.trim().split(RegExp(r'\s+')).first;

    final refuerzos = ruta
        .where((i) => i.recomendacion.tipo == TipoRecomendacion.reforzar)
        .take(maximoRefuerzos)
        .toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      encabezado,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColoresApp.apagado,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hola, $primerNombre',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              _Avatar(inicial: primerNombre, alPresionar: onAbrirPerfil),
            ],
          ),
          const SizedBox(height: 20),
          _TarjetaHoy(
            dia: dia,
            practicados: {for (final item in ruta) ?item.temaId},
            curso: _curso,
            onAbrirTema: onAbrirTema,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Para reforzar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onVerRuta,
                style: TextButton.styleFrom(
                  foregroundColor: ColoresApp.apagado,
                ),
                child: const Text('Ver ruta'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (refuerzos.isEmpty)
            _Panel(
              child: Text(
                ruta.isEmpty
                    ? 'Resuelve las prácticas de tus temas y aquí verás qué te conviene reforzar.'
                    : 'Nada urgente por reforzar. Sigue con tu ruta.',
                style: const TextStyle(color: ColoresApp.apagado),
              ),
            )
          else
            for (final item in refuerzos)
              _TarjetaRefuerzo(
                item: item,
                tema: item.temaId == null ? null : _tema(item.temaId!),
                curso: _curso,
                onAbrirTema: onAbrirTema,
              ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String inicial;
  final VoidCallback alPresionar;

  const _Avatar({required this.inicial, required this.alPresionar});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Perfil',
      excludeSemantics: true,
      child: InkWell(
        onTap: alPresionar,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ColoresApp.panel,
            border: Border.all(color: ColoresApp.borde),
          ),
          child: Text(
            inicial.isEmpty ? '?' : inicial[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ColoresApp.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: child,
    );
  }
}

class _TarjetaHoy extends StatelessWidget {
  final ContextoDiaEstudiante dia;
  final Set<String> practicados;
  final Curso? Function(String? id) curso;
  final void Function(Tema tema, Curso? curso) onAbrirTema;

  const _TarjetaHoy({
    required this.dia,
    required this.practicados,
    required this.curso,
    required this.onAbrirTema,
  });

  @override
  Widget build(BuildContext context) {
    if (dia.dia == null) {
      return const _Panel(
        child: Text(
          'Hoy no tienes temas. Aprovecha para descansar o repasar.',
          style: TextStyle(color: ColoresApp.apagado),
        ),
      );
    }

    final temas = [
      for (final actividad in dia.actividades)
        for (final tema in dia.temas)
          if (tema.id == actividad.temaId) tema,
    ];

    if (temas.isEmpty) {
      return const _Panel(
        child: Text(
          'Los temas de hoy todavía no han sido publicados.',
          style: TextStyle(color: ColoresApp.apagado),
        ),
      );
    }

    final hechos = temas.where((t) => practicados.contains(t.id)).length;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tu ruta de hoy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$hechos de ${temas.length} temas',
                style: const TextStyle(fontSize: 13, color: ColoresApp.apagado),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: hechos / temas.length,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, tema) in temas.indexed)
            _FilaTema(
              numero: i + 1,
              tema: tema,
              curso: curso(tema.cursoId),
              practicado: practicados.contains(tema.id),
              onAbrirTema: onAbrirTema,
            ),
        ],
      ),
    );
  }
}

class _FilaTema extends StatelessWidget {
  final int numero;
  final Tema tema;
  final Curso? curso;
  final bool practicado;
  final void Function(Tema tema, Curso? curso) onAbrirTema;

  const _FilaTema({
    required this.numero,
    required this.tema,
    required this.curso,
    required this.practicado,
    required this.onAbrirTema,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onAbrirTema(tema, curso),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: practicado ? const Color(0x1FFFFFFF) : null,
                borderRadius: BorderRadius.circular(12),
                border: practicado
                    ? null
                    : Border.all(color: ColoresApp.ambar, width: 1.5),
              ),
              child: practicado
                  ? const Icon(Icons.check, size: 18)
                  : Text(
                      '$numero',
                      style: const TextStyle(
                        color: ColoresApp.ambar,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tema.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${curso?.nombre ?? ''} · ${practicado ? 'practicado' : 'pendiente'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColoresApp.apagado,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ColoresApp.tenue),
          ],
        ),
      ),
    );
  }
}

class _TarjetaRefuerzo extends StatelessWidget {
  final ItemMiRuta item;
  final Tema? tema;
  final Curso? Function(String? id) curso;
  final void Function(Tema tema, Curso? curso) onAbrirTema;

  const _TarjetaRefuerzo({
    required this.item,
    required this.tema,
    required this.curso,
    required this.onAbrirTema,
  });

  @override
  Widget build(BuildContext context) {
    final temaActual = tema;
    final cursoActual = curso(temaActual?.cursoId);
    final porcentaje = (item.estado.valor * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: temaActual == null
            ? null
            : () => onAbrirTema(temaActual, cursoActual),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ColoresApp.panel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ColoresApp.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'REFORZAR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: ColoresApp.naranja,
                      ),
                    ),
                  ),
                  Text(
                    'Dominio $porcentaje %',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ColoresApp.apagado,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                temaActual?.titulo ?? item.estado.habilidadId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${cursoActual?.nombre ?? ''} · ${item.cantidadEvidencias} respuestas',
                style: const TextStyle(fontSize: 13, color: ColoresApp.apagado),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: item.estado.valor,
                  minHeight: 5,
                  color: ColoresApp.naranja,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
