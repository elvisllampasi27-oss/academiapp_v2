import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../graficos.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'matricular_dialogo.dart';
import 'modelo_estudiantes.dart';
import 'repositorio_estudiantes_admin.dart';
import 'vista_estudiante.dart';

typedef _Datos = (
  List<EstudianteAdmin>,
  List<VersionAcademica>,
  Map<String, Curriculo>,
);

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

  late Future<_Datos> _datos = _cargar();
  late FiltroEstudiantes _filtro = widget.filtroInicial;
  String _texto = '';
  String? _versionId;
  int _pagina = 0;

  /// Estudiantes, versiones y el temario de cada versión con matrículas
  /// (1 lectura por versión) para saber de cuántos días es su ciclo.
  Future<_Datos> _cargar() async {
    final (estudiantes, versiones) = await (
      widget.repositorio.estudiantes(),
      widget.repositorio.versiones(),
    ).wait;
    final ids = {for (final e in estudiantes) ?e.matricula?.versionId};
    final temarios = <String, Curriculo>{};
    Future<void> leer(String id) async {
      try {
        temarios[id] = await widget.repositorio.curriculo(id);
      } catch (_) {
        // Sin temario cargado: se muestra el día sin el total.
      }
    }

    await Future.wait([for (final id in ids) leer(id)]);
    return (estudiantes, versiones, temarios);
  }

  void _recargar() => setState(() {
    _datos = _cargar();
  });

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
        final (estudiantes, versiones, temarios) = datos;
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
              temarios: temarios,
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

class _Tabla extends StatefulWidget {
  final List<EstudianteAdmin> estudiantes;
  final DateTime hoy;
  final Map<String, String> nombreVersion;
  final Map<String, Curriculo> temarios;
  final ValueChanged<String> onAbrir;

  const _Tabla({
    required this.estudiantes,
    required this.hoy,
    required this.nombreVersion,
    required this.temarios,
    required this.onAbrir,
  });

  @override
  State<_Tabla> createState() => _TablaState();
}

class _TablaState extends State<_Tabla> {
  /// Anchos fijos: la columna Estudiante toma lo que sobre. Si la ventana es
  /// angosta, la tabla se desliza de lado en vez de partir las palabras.
  static const _columnas = [
    ('ESTUDIANTE', null),
    ('CARRERA', 200.0),
    ('VERSIÓN', 160.0),
    ('INICIO', 90.0),
    ('AVANCE DEL CICLO', 230.0),
    ('PLAN', 130.0),
    ('ÚLTIMA ACTIVIDAD', 150.0),
    ('ESTADO', 140.0),
  ];
  static const _anchoMinimo = 1410.0;

  final _desplazamiento = ScrollController();

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  Widget _fila(
    List<Widget> celdas, {
    VoidCallback? onTap,
    bool cabecera = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: cabecera ? 14 : 13,
        ),
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
                SizedBox(
                  width: ancho,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: celdas[i],
                  ),
                )
              else
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: celdas[i],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Text _unaLinea(String texto, TextStyle estilo) => Text(
    texto,
    style: estilo,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final hoy = widget.hoy;
    final apagado = TextStyle(color: p.apagado, fontSize: 13);

    return TarjetaPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth < _anchoMinimo ? _anchoMinimo : c.maxWidth;
          return Scrollbar(
            controller: _desplazamiento,
            thumbVisibility: c.maxWidth < _anchoMinimo,
            child: SingleChildScrollView(
              controller: _desplazamiento,
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: c.maxWidth < _anchoMinimo ? 12 : 0,
                ),
                child: SizedBox(
                  width: ancho,
                  child: Column(
                    children: [
                      _fila(cabecera: true, [
                        for (final (titulo, _) in _columnas)
                          _unaLinea(
                            titulo,
                            TextStyle(
                              color: p.tenue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                      ]),
                      if (widget.estudiantes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Ningún estudiante coincide con los filtros.',
                            style: apagado,
                          ),
                        ),
                      for (final e in widget.estudiantes)
                        _fila(onTap: () => widget.onAbrir(e.uid), [
                          Row(
                            children: [
                              AvatarIniciales(e.nombre),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _unaLinea(
                                      e.nombre,
                                      const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    _unaLinea(
                                      e.correo,
                                      TextStyle(color: p.apagado, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          _unaLinea(e.carrera ?? '—', apagado),
                          _unaLinea(
                            widget.nombreVersion[e.matricula?.versionId] ??
                                e.matricula?.versionId ??
                                '—',
                            apagado,
                          ),
                          _unaLinea(
                            e.matricula == null
                                ? '—'
                                : fechaBreve(e.matricula!.fechaInicioAcademico),
                            TextStyle(color: p.texto, fontSize: 13),
                          ),
                          _AvanceCelda(
                            situacion: situacion(e, hoy),
                            avance: avanceCiclo(
                              e,
                              widget.temarios[e.matricula?.versionId],
                              hoy,
                            ),
                            inicio: e.matricula?.fechaInicioAcademico,
                            hoy: hoy,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: e.esPremiumEn(hoy)
                                ? Insignia(
                                    'Premium · ${fechaBreve(e.premiumHasta!)}',
                                    tono: TonoInsignia.acento,
                                  )
                                : const Insignia('Gratis'),
                          ),
                          _unaLinea(
                            haceCuanto(e.ultimaActividad, hoy),
                            TextStyle(
                              fontSize: 13,
                              color: sinActividad(e, hoy) ? p.alerta : p.texto,
                            ),
                          ),
                          PuntoSituacion(situacion(e, hoy)),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Barra que crece cada día del ciclo (como un medidor) y su porcentaje.
class _AvanceCelda extends StatelessWidget {
  final SituacionEstudiante situacion;
  final AvanceCiclo? avance;
  final DateTime? inicio;
  final DateTime hoy;

  const _AvanceCelda({
    required this.situacion,
    required this.avance,
    required this.inicio,
    required this.hoy,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final a = avance;
    if (a == null) {
      return Text('—', style: TextStyle(color: p.tenue));
    }

    final String texto;
    if (situacion == SituacionEstudiante.programado && inicio != null) {
      final faltan = DateTime(
        inicio!.year,
        inicio!.month,
        inicio!.day,
      ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
      texto = faltan <= 1 ? 'Empieza mañana' : 'Empieza en $faltan días';
    } else {
      texto = a.total == null ? 'Día ${a.dia}' : 'Día ${a.dia} de ${a.total}';
    }
    final fraccion = a.fraccion ?? 0;
    final color = switch (situacion) {
      SituacionEstudiante.suspendido => p.alerta,
      SituacionEstudiante.finalizado => p.tenue,
      _ => p.acento,
    };

    final restantes = a.total == null ? null : a.total! - a.dia;
    return Row(
      children: [
        AnilloAvance(fraccion, tamano: 38, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                texto,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              if (restantes != null && situacion == SituacionEstudiante.activo)
                Text(
                  restantes <= 0
                      ? 'terminó el temario'
                      : 'faltan $restantes días',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.tenue, fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
