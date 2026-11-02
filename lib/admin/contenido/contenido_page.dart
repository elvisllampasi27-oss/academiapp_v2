import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/curso.dart';
import '../../features/academic/domain/entities/tema.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../estudiantes/repositorio_estudiantes_admin.dart';
import '../tema_panel.dart';
import '../versiones/modelo_versiones.dart';
import '../widgets_panel.dart';
import 'editor_tema_page.dart';
import 'modelo_contenido.dart';
import 'repositorio_contenido_admin.dart';

/// Cursos y temas de una versión con lo que le falta a cada tema.
class ContenidoPage extends StatefulWidget {
  final RepositorioContenidoAdmin contenido;
  final RepositorioEstudiantesAdmin estudiantes;
  final GeneradorQuiz generador;

  const ContenidoPage({
    super.key,
    required this.contenido,
    required this.estudiantes,
    required this.generador,
  });

  @override
  State<ContenidoPage> createState() => _ContenidoPageState();
}

class _ContenidoPageState extends State<ContenidoPage> {
  late final Future<List<VersionAcademica>> _versiones = widget.estudiantes
      .versiones()
      .then(
        (todas) => todas
            .where((v) => v.estado != EstadoVersionAcademica.archivada)
            .toList(),
      );
  String? _versionId;
  Future<ResumenContenido>? _resumen;
  String? _cursoId;
  FiltroTemas _filtro = FiltroTemas.todos;
  Tema? _editando;

  void _elegirVersion(String id) => setState(() {
    _versionId = id;
    _resumen = widget.contenido.resumen(id);
    _cursoId = null;
  });

  void _recargar() => setState(() {
    _resumen = widget.contenido.resumen(_versionId!);
  });

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _versiones,
      onReintentar: () => setState(() {}),
      builder: (context, versiones) {
        if (versiones.isEmpty) {
          return const Center(child: Text('No hay versiones.'));
        }
        if (_versionId == null) {
          final porDefecto =
              versiones
                  .where((v) => v.estado == EstadoVersionAcademica.activa)
                  .firstOrNull ??
              versiones.first;
          _versionId = porDefecto.id;
          _resumen = widget.contenido.resumen(porDefecto.id);
        }
        final version = versiones.firstWhere((v) => v.id == _versionId);

        return FuturoPanel(
          futuro: _resumen!,
          onReintentar: _recargar,
          builder: (context, resumen) {
            final editando = _editando;
            if (editando != null) {
              final curso = resumen.curriculo.cursos.firstWhere(
                (c) => c.id == editando.cursoId,
              );
              return EditorTemaPage(
                key: ValueKey(editando.id),
                versionId: version.id,
                tema: editando,
                curso: curso,
                material:
                    resumen.material[editando.id] ??
                    MaterialTema(temaId: editando.id),
                publicado: resumen.publicados.contains(editando.id),
                repositorio: widget.contenido,
                generador: widget.generador,
                onVolver: (cambio) => setState(() {
                  _editando = null;
                  if (cambio) _resumen = widget.contenido.resumen(version.id);
                }),
              );
            }
            return _lista(versiones, version, resumen);
          },
        );
      },
    );
  }

  Widget _lista(
    List<VersionAcademica> versiones,
    VersionAcademica version,
    ResumenContenido r,
  ) {
    final p = PaletaPanel.de(context);
    final cursos = [...r.curriculo.cursos.where((c) => c.activo)]
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final curso =
        cursos.where((c) => c.id == _cursoId).firstOrNull ?? cursos.firstOrNull;
    final dias = {
      for (final d in calendarioVersion(r.curriculo, version.fechaApertura))
        for (final t in d.temas) t: d.numero,
    };

    return PaginaPanel(
      children: [
        EncabezadoPanel(
          titulo: 'Cursos y temas',
          subtitulo:
              '${version.nombre} · el porcentaje es el material completo de '
              'cada curso (video, separata, contenidos y quiz).',
          acciones: [
            OutlinedButton.icon(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        if (versiones.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in versiones)
                ChoiceChip(
                  label: Text(v.nombre),
                  selected: v.id == version.id,
                  onSelected: (_) => _elegirVersion(v.id),
                ),
            ],
          ),
        if (curso == null)
          const TarjetaPanel(child: Text('Esta versión no tiene cursos.'))
        else
          DosColumnas(
            flexPrincipal: 1,
            flexLateral: 3,
            principal: TarjetaPanel(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (final c in cursos)
                    _ItemCurso(
                      curso: c,
                      avance: completoCurso(c.id, r.curriculo, r.material),
                      elegido: c.id == curso.id,
                      onTap: () => setState(() => _cursoId = c.id),
                    ),
                ],
              ),
            ),
            lateral: ColumnaPanel(
              espacio: 12,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        curso.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final f in FiltroTemas.values)
                      ChoiceChip(
                        label: Text(f.etiqueta),
                        selected: _filtro == f,
                        onSelected: (_) => setState(() => _filtro = f),
                      ),
                  ],
                ),
                _TablaTemas(
                  temas: [
                    for (final t in r.curriculo.temasDe(curso.id))
                      if (pasaFiltro(
                        _filtro,
                        r.material[t.id],
                        r.publicados.contains(t.id),
                      ))
                        t,
                  ],
                  material: r.material,
                  publicados: r.publicados,
                  dias: dias,
                  onAbrir: (t) => setState(() => _editando = t),
                ),
                Text(
                  'El día es el del calendario contando desde la apertura '
                  '(${fechaBreve(version.fechaApertura)}).',
                  style: TextStyle(color: p.tenue, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemCurso extends StatelessWidget {
  final Curso curso;
  final double avance;
  final bool elegido;
  final VoidCallback onTap;

  const _ItemCurso({
    required this.curso,
    required this.avance,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return Material(
      color: elegido ? const Color(0x14FFFFFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      curso.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${(avance * 100).round()} %',
                    style: TextStyle(color: p.apagado, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              BarraAvance(
                avance,
                alto: 4,
                color: avance >= 1 ? p.secundario : p.acento,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TablaTemas extends StatelessWidget {
  final List<Tema> temas;
  final Map<String, MaterialTema> material;
  final Set<String> publicados;
  final Map<String, int> dias;
  final ValueChanged<Tema> onAbrir;

  const _TablaTemas({
    required this.temas,
    required this.material,
    required this.publicados,
    required this.dias,
    required this.onAbrir,
  });

  static const _columnas = [
    ('#', 44.0),
    ('TEMA', null),
    ('DÍA', 64.0),
    ('ESTADO', 120.0),
    ('VIDEO', 70.0),
    ('SEPARATA', 90.0),
    ('CONTENIDOS', 100.0),
    ('QUIZ', 130.0),
  ];

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);

    Widget fila(
      List<Widget> celdas, {
      VoidCallback? onTap,
      bool cabecera = false,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cabecera ? PaletaPanel.bordeFuerte : PaletaPanel.linea,
            ),
          ),
        ),
        child: Row(
          children: [
            for (var i = 0; i < celdas.length; i++)
              if (_columnas[i].$2 case final ancho?)
                SizedBox(width: ancho, child: celdas[i])
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: celdas[i],
                  ),
                ),
          ],
        ),
      ),
    );

    Widget marca(bool listo) => Align(
      alignment: Alignment.centerLeft,
      child: Icon(
        listo ? Icons.check_circle : Icons.cancel_outlined,
        size: 18,
        color: listo ? p.secundario : p.alerta,
      ),
    );

    return TarjetaPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth < 900 ? 900.0 : c.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: ancho,
              child: Column(
                children: [
                  fila(cabecera: true, [
                    for (final (t, _) in _columnas)
                      Text(
                        t,
                        maxLines: 1,
                        style: TextStyle(
                          color: p.tenue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ]),
                  if (temas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        'Ningún tema coincide con el filtro.',
                        style: TextStyle(color: p.apagado),
                      ),
                    ),
                  for (final t in temas)
                    () {
                      final m = material[t.id] ?? MaterialTema(temaId: t.id);
                      final publicado = publicados.contains(t.id);
                      final quiz = m.tieneQuiz
                          ? Insignia(
                              '${m.quizzes.values.where((q) => q.publicado).length} '
                              'nivel(es)',
                              tono: TonoInsignia.secundario,
                            )
                          : m.quizBorrador
                          ? const Insignia(
                              'Borrador',
                              tono: TonoInsignia.acento,
                            )
                          : const Insignia('—');
                      return fila(onTap: () => onAbrir(t), [
                        Text('${t.orden}', style: TextStyle(color: p.apagado)),
                        Text(
                          t.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          dias[t.id] == null ? '—' : 'Día ${dias[t.id]}',
                          style: TextStyle(color: p.apagado),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: publicado
                              ? const Insignia(
                                  'Publicado',
                                  tono: TonoInsignia.secundario,
                                )
                              : const Insignia('Sin publicar'),
                        ),
                        marca(m.video != null),
                        marca(m.separata != null),
                        Text(
                          '${m.contenidos.length}',
                          style: TextStyle(
                            color: m.contenidos.isEmpty ? p.alerta : p.apagado,
                          ),
                        ),
                        Align(alignment: Alignment.centerLeft, child: quiz),
                      ]);
                    }(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
