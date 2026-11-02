import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/version_academica.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'matricular_dialogo.dart';
import 'modelo_estudiantes.dart';
import 'repositorio_estudiantes_admin.dart';
import 'vista_estudiante.dart';

/// Lista de estudiantes con filtros. Al tocar uno se abre su ficha.
class EstudiantesPage extends StatefulWidget {
  final RepositorioEstudiantesAdmin repositorio;
  final ValueChanged<String> onAbrir;
  final FiltroEstudiantes filtroInicial;
  final DateTime Function() ahora;

  const EstudiantesPage({
    super.key,
    required this.repositorio,
    required this.onAbrir,
    this.filtroInicial = FiltroEstudiantes.todos,
    this.ahora = DateTime.now,
  });

  @override
  State<EstudiantesPage> createState() => _EstudiantesPageState();
}

class _EstudiantesPageState extends State<EstudiantesPage> {
  static const _porPagina = 25;

  late Future<(List<EstudianteAdmin>, List<VersionAcademica>)> _datos =
      _cargar();
  late FiltroEstudiantes _filtro = widget.filtroInicial;
  String _texto = '';
  String? _versionId;
  int _pagina = 0;

  Future<(List<EstudianteAdmin>, List<VersionAcademica>)> _cargar() =>
      (widget.repositorio.estudiantes(), widget.repositorio.versiones()).wait;

  void _recargar() => setState(() => _datos = _cargar());

  void _cambiar(VoidCallback cambio) => setState(() {
    cambio();
    _pagina = 0;
  });

  Future<void> _matricular(List<EstudianteAdmin> estudiantes) async {
    final hecho = await mostrarMatricular(
      context,
      repositorio: widget.repositorio,
      estudiantes: estudiantes,
      ahora: widget.ahora,
    );
    if (hecho && mounted) {
      avisarPanel(context, 'Estudiante matriculado.');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel(
      futuro: _datos,
      onReintentar: _recargar,
      builder: (context, datos) {
        final (estudiantes, versiones) = datos;
        final hoy = widget.ahora();
        final filtrados = filtrarEstudiantes(
          estudiantes,
          hoy: hoy,
          filtro: _filtro,
          texto: _texto,
          versionId: _versionId,
        );
        final paginas = (filtrados.length / _porPagina).ceil();
        final pagina = _pagina.clamp(0, paginas == 0 ? 0 : paginas - 1).toInt();
        final visibles = filtrados
            .skip(pagina * _porPagina)
            .take(_porPagina)
            .toList();
        final nombreVersion = {for (final v in versiones) v.id: v.nombre};

        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Estudiantes',
              subtitulo:
                  'Matriculados y su avance. Haz clic en un estudiante para '
                  'ver su ficha.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
                FilledButton.icon(
                  onPressed: () => _matricular(estudiantes),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Matricular estudiante'),
                ),
              ],
            ),
            _filtros(versiones),
            _Tabla(
              estudiantes: visibles,
              hoy: hoy,
              nombreVersion: nombreVersion,
              onAbrir: widget.onAbrir,
            ),
            _pie(filtrados.length, pagina, paginas),
          ],
        );
      },
    );
  }

  Widget _filtros(List<VersionAcademica> versiones) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: (t) => _cambiar(() => _texto = t),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o correo',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (versiones.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Versión',
            onSelected: (v) =>
                _cambiar(() => _versionId = v.isEmpty ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: '',
                child: Text('Todas las versiones'),
              ),
              for (final v in versiones)
                PopupMenuItem(value: v.id, child: Text(v.nombre)),
            ],
            child: Chip(
              avatar: const Icon(Icons.layers_outlined, size: 16),
              label: Text(
                versiones
                        .where((v) => v.id == _versionId)
                        .firstOrNull
                        ?.nombre ??
                    'Todas las versiones',
              ),
            ),
          ),
        for (final f in FiltroEstudiantes.values)
          ChoiceChip(
            label: Text(f.etiqueta),
            selected: _filtro == f,
            onSelected: (_) => _cambiar(() => _filtro = f),
          ),
      ],
    );
  }

  Widget _pie(int total, int pagina, int paginas) {
    final p = PaletaPanel.de(context);
    final desde = total == 0 ? 0 : pagina * _porPagina + 1;
    final hasta = (pagina * _porPagina + _porPagina).clamp(0, total);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$desde–$hasta de $total',
            style: TextStyle(color: p.apagado, fontSize: 13),
          ),
        ),
        OutlinedButton(
          onPressed: pagina > 0
              ? () => setState(() => _pagina = pagina - 1)
              : null,
          child: const Text('Anterior'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: pagina < paginas - 1
              ? () => setState(() => _pagina = pagina + 1)
              : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}

class _Tabla extends StatelessWidget {
  final List<EstudianteAdmin> estudiantes;
  final DateTime hoy;
  final Map<String, String> nombreVersion;
  final ValueChanged<String> onAbrir;

  const _Tabla({
    required this.estudiantes,
    required this.hoy,
    required this.nombreVersion,
    required this.onAbrir,
  });

  static const _columnas = [
    ('ESTUDIANTE', 3),
    ('CARRERA', 2),
    ('VERSIÓN', 2),
    ('MATRÍCULA', 1),
    ('INICIO · DÍA', 2),
    ('ÚLTIMA ACTIVIDAD', 2),
    ('ESTADO', 1),
  ];

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);

    Widget fila(List<Widget> celdas, {VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(
                flex: _columnas[i].$2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: celdas[i],
                ),
              ),
          ],
        ),
      ),
    );

    final apagado = TextStyle(color: p.apagado, fontSize: 13);

    return TarjetaPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth < 1000 ? 1000.0 : c.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: ancho,
              child: Column(
                children: [
                  fila([
                    for (final (titulo, _) in _columnas)
                      Text(
                        titulo,
                        style: TextStyle(
                          color: p.tenue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ]),
                  if (estudiantes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Ningún estudiante coincide con los filtros.',
                        style: apagado,
                      ),
                    ),
                  for (final e in estudiantes)
                    fila(onTap: () => onAbrir(e.uid), [
                      Row(
                        children: [
                          AvatarIniciales(e.nombre),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  e.correo,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.apagado,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(e.carrera ?? '—', style: apagado),
                      Text(
                        nombreVersion[e.matricula?.versionId] ??
                            e.matricula?.versionId ??
                            '—',
                        style: apagado,
                      ),
                      Text(
                        e.matricula == null
                            ? '—'
                            : fechaBreve(e.matricula!.fechaMatricula),
                      ),
                      Text(textoInicio(e, hoy)),
                      Text(
                        haceCuanto(e.ultimaActividad, hoy),
                        style: TextStyle(
                          color: sinActividad(e, hoy) ? p.alerta : p.texto,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: insigniaSituacion(situacion(e, hoy)),
                      ),
                    ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
