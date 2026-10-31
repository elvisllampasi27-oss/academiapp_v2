import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../../../core/presentation/texto.dart';
import '../../domain/entities/curriculo.dart';
import '../../domain/entities/curso.dart';

/// Pestaña Cursos: grilla de cursos con filtro por área y buscador.
class CursosPage extends StatefulWidget {
  final Curriculo curriculo;
  final Set<String> publicados;
  final void Function(Curso curso) onAbrirCurso;

  const CursosPage({
    super.key,
    required this.curriculo,
    required this.publicados,
    required this.onAbrirCurso,
  });

  @override
  State<CursosPage> createState() => _CursosPageState();
}

class _CursosPageState extends State<CursosPage> {
  String? _areaId;
  String _busqueda = '';

  List<Curso> _visibles() {
    final consulta = normalizarTexto(_busqueda.trim());

    return widget.curriculo.cursos.where((curso) {
      if (_areaId != null && curso.areaId != _areaId) return false;
      if (consulta.isEmpty) return true;
      if (normalizarTexto(curso.nombre).contains(consulta)) return true;
      return widget.curriculo
          .temasDe(curso.id)
          .any((t) => normalizarTexto(t.titulo).contains(consulta));
    }).toList()..sort((a, b) => a.orden.compareTo(b.orden));
  }

  @override
  Widget build(BuildContext context) {
    final cursos = _visibles();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverList.list(
              children: [
                const Text(
                  'Cursos',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (texto) => setState(() => _busqueda = texto),
                  decoration: InputDecoration(
                    hintText: 'Buscar curso o tema',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: ColoresApp.panel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ColoresApp.borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ColoresApp.borde),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        texto: 'Todos',
                        activo: _areaId == null,
                        alPresionar: () => setState(() => _areaId = null),
                      ),
                      for (final area in widget.curriculo.areas)
                        _Chip(
                          texto: area.nombre,
                          activo: _areaId == area.id,
                          alPresionar: () => setState(() => _areaId = area.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (cursos.isEmpty)
                  const Text(
                    'No hay cursos que coincidan.',
                    style: TextStyle(color: ColoresApp.apagado),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: [
                for (final curso in cursos)
                  _TarjetaCurso(
                    curso: curso,
                    total: widget.curriculo.temasDe(curso.id).length,
                    publicados: widget.curriculo
                        .temasDe(curso.id)
                        .where((t) => widget.publicados.contains(t.id))
                        .length,
                    alPresionar: () => widget.onAbrirCurso(curso),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback alPresionar;

  const _Chip({
    required this.texto,
    required this.activo,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(texto),
        selected: activo,
        onSelected: (_) => alPresionar(),
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: activo ? Colors.transparent : ColoresApp.bordeFuerte,
        ),
        selectedColor: ColoresApp.texto,
        backgroundColor: Colors.transparent,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: activo ? ColoresApp.fondo : ColoresApp.apagado,
        ),
      ),
    );
  }
}

class _TarjetaCurso extends StatelessWidget {
  final Curso curso;
  final int total;
  final int publicados;
  final VoidCallback alPresionar;

  const _TarjetaCurso({
    required this.curso,
    required this.total,
    required this.publicados,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: ColoresApp.borde),
      ),
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  siglas(curso.nombre),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  curso.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$publicados de $total temas',
                style: const TextStyle(fontSize: 12, color: ColoresApp.apagado),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : publicados / total,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
