import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/tema.dart';

enum EstadoTemaCurso { practicado, hoy, disponible, proximamente }

/// Temas de un curso en grilla, con su estado para el estudiante.
class CursoDetallePage extends StatelessWidget {
  final Curso curso;
  final String? nombreArea;
  final List<Tema> temas;
  final Set<String> publicados;
  final Set<String> practicados;
  final Set<String> hoy;
  final void Function(Tema tema) onAbrirTema;

  const CursoDetallePage({
    super.key,
    required this.curso,
    required this.temas,
    required this.publicados,
    required this.practicados,
    required this.hoy,
    required this.onAbrirTema,
    this.nombreArea,
  });

  EstadoTemaCurso _estado(Tema tema) {
    if (!publicados.contains(tema.id)) return EstadoTemaCurso.proximamente;
    if (practicados.contains(tema.id)) return EstadoTemaCurso.practicado;
    if (hoy.contains(tema.id)) return EstadoTemaCurso.hoy;
    return EstadoTemaCurso.disponible;
  }

  @override
  Widget build(BuildContext context) {
    final disponibles = temas.where((t) => publicados.contains(t.id)).length;

    return Scaffold(
      appBar: AppBar(),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList.list(
              children: [
                Text(
                  [?nombreArea, '${temas.length} temas'].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColoresApp.apagado,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  curso.nombre,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$disponibles de ${temas.length} temas publicados',
                  style: const TextStyle(
                    fontSize: 13,
                    color: ColoresApp.apagado,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: temas.isEmpty ? 0 : disponibles / temas.length,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final tema in temas)
                  _TarjetaTema(
                    tema: tema,
                    estado: _estado(tema),
                    alPresionar: () => onAbrirTema(tema),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaTema extends StatelessWidget {
  final Tema tema;
  final EstadoTemaCurso estado;
  final VoidCallback alPresionar;

  const _TarjetaTema({
    required this.tema,
    required this.estado,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final bloqueado = estado == EstadoTemaCurso.proximamente;
    final esHoy = estado == EstadoTemaCurso.hoy;

    final etiqueta = switch (estado) {
      EstadoTemaCurso.practicado => const _Etiqueta(
        icono: Icons.check,
        texto: 'Practicado',
        color: ColoresApp.apagado,
      ),
      EstadoTemaCurso.hoy => const Text(
        'HOY',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: ColoresApp.ambar,
        ),
      ),
      EstadoTemaCurso.disponible => const _Etiqueta(
        texto: 'Disponible',
        color: ColoresApp.apagado,
      ),
      EstadoTemaCurso.proximamente => const _Etiqueta(
        icono: Icons.lock_outline,
        texto: 'Próximamente',
        color: ColoresApp.tenue,
      ),
    };

    return Material(
      color: esHoy
          ? const Color(0x14F2C14E)
          : bloqueado
          ? const Color(0x05FFFFFF)
          : ColoresApp.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esHoy
              ? const Color(0x73F2C14E)
              : bloqueado
              ? const Color(0x0FFFFFFF)
              : ColoresApp.borde,
        ),
      ),
      child: InkWell(
        onTap: bloqueado ? null : alPresionar,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tema.orden.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ColoresApp.tenue,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  tema.titulo,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: bloqueado ? ColoresApp.apagado : ColoresApp.texto,
                  ),
                ),
              ),
              etiqueta,
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData? icono;
  final String texto;
  final Color color;

  const _Etiqueta({required this.texto, required this.color, this.icono});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(texto, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
