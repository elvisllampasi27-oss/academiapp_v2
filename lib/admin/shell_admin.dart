import 'package:flutter/material.dart';

import 'analitica/analitica_page.dart';
import 'avisos/avisos_page.dart';
import 'avisos/repositorio_avisos_admin.dart';
import 'bandeja/bandeja_page.dart';
import 'bandeja/repositorio_bandeja.dart';
import 'estudiantes/estudiantes_page.dart';
import 'estudiantes/ficha_estudiante_page.dart';
import 'estudiantes/modelo_estudiantes.dart';
import 'estudiantes/repositorio_estudiantes_admin.dart';
import 'examenes/examenes_admin_page.dart';
import 'configuracion/configuracion_page.dart';
import 'contenido/contenido_page.dart';
import 'contenido/repositorio_contenido_admin.dart';
import 'examenes/repositorio_examenes_admin.dart';
import 'pagos/cupones_page.dart';
import 'ranking/ranking_admin.dart';
import 'ranking/ranking_page.dart';
import 'pagos/pagos_page.dart';
import 'pagos/repositorio_pagos_admin.dart';
import 'graficos.dart';
import 'logo_puntos.dart';
import 'resumen/resumen_page.dart';
import 'sistema/estado_sistema_page.dart';
import 'sistema/sonda_sistema.dart';
import 'tema_panel.dart';
import 'versiones/repositorio_versiones_admin.dart';
import 'versiones/versiones_page.dart';
import 'widgets_panel.dart';

enum SeccionPanel {
  resumen,
  analitica,
  estudiantes,
  pagos,
  cupones,
  versiones,
  ranking,
  avisos,
  contenido,
  examenes,
  semanales,
  reportes,
  estado,
  configuracion,
}

/// Estructura del panel: menú lateral por grupos y la sección elegida.
class ShellAdmin extends StatefulWidget {
  final String correo;
  final VoidCallback onSalir;
  final RepositorioEstudiantesAdmin repositorioEstudiantes;
  final RepositorioExamenesAdmin repositorioExamenes;
  final RepositorioExamenesAdmin repositorioSemanales;
  final RepositorioRankingAdmin repositorioRanking;
  final RepositorioPagosAdmin repositorioPagos;
  final RepositorioAcademiaAdmin repositorioAcademia;
  final RepositorioVersionesAdmin repositorioVersiones;
  final RepositorioContenidoAdmin repositorioContenido;
  final GeneradorQuiz generadorQuiz;
  final RepositorioBandeja repositorioBandeja;
  final RepositorioAvisosAdmin repositorioAvisos;
  final SondaSistema sondaSistema;
  final DateTime Function() ahora;

  const ShellAdmin({
    super.key,
    required this.correo,
    required this.onSalir,
    required this.repositorioEstudiantes,
    required this.repositorioExamenes,
    required this.repositorioSemanales,
    required this.repositorioRanking,
    required this.repositorioPagos,
    required this.repositorioAcademia,
    required this.repositorioVersiones,
    required this.repositorioContenido,
    required this.generadorQuiz,
    required this.repositorioBandeja,
    required this.repositorioAvisos,
    required this.sondaSistema,
    this.ahora = DateTime.now,
  });

  @override
  State<ShellAdmin> createState() => _ShellAdminState();
}

class _ShellAdminState extends State<ShellAdmin> {
  SeccionPanel _seccion = SeccionPanel.resumen;
  String? _fichaUid;
  FiltroEstudiantes _filtro = FiltroEstudiantes.todos;

  /// Cambia cada vez que se entra a Estudiantes desde otro lado, para que
  /// la lista se vuelva a leer con el filtro pedido.
  int _visita = 0;

  late final Stream<int> _pendientes = widget.repositorioPagos.pendientes();
  late final Stream<int> _reportesNuevos = widget.repositorioBandeja.nuevos();

  /// A dónde llevar Exámenes o Cursos y temas al venir de un reporte.
  (String, String?)? _destino;

  void _ir(SeccionPanel s) => setState(() {
    _seccion = s;
    _fichaUid = null;
    _filtro = FiltroEstudiantes.todos;
    _destino = null;
    _visita++;
  });

  void _irA(SeccionPanel s, (String, String?) destino) => setState(() {
    _seccion = s;
    _destino = destino;
    _visita++;
  });

  void _verEstudiantes(FiltroEstudiantes filtro) => setState(() {
    _seccion = SeccionPanel.estudiantes;
    _fichaUid = null;
    _filtro = filtro;
    _visita++;
  });

  void _abrirEstudiante(String uid) => setState(() {
    _seccion = SeccionPanel.estudiantes;
    _fichaUid = uid;
  });

  Widget _pagina() {
    return switch (_seccion) {
      SeccionPanel.resumen => ResumenPage(
        repositorio: widget.repositorioEstudiantes,
        onAbrirEstudiante: _abrirEstudiante,
        onVerEstudiantes: _verEstudiantes,
        pagos: widget.repositorioPagos,
        onVerPagos: () => _ir(SeccionPanel.pagos),
        correoAdmin: widget.correo,
        ahora: widget.ahora,
      ),
      SeccionPanel.analitica => AnaliticaPage(
        estudiantes: widget.repositorioEstudiantes,
        pagos: widget.repositorioPagos,
        onVerEstudiantes: _verEstudiantes,
        ahora: widget.ahora,
      ),
      SeccionPanel.avisos => AvisosPage(
        repositorio: widget.repositorioAvisos,
        versiones: widget.repositorioEstudiantes.versiones,
        ahora: widget.ahora,
      ),
      SeccionPanel.estado => EstadoSistemaPage(
        sonda: widget.sondaSistema,
        // Streams propios: los del menú ya tienen quien los escuche.
        pagosPendientes: widget.repositorioPagos.pendientes(),
        reportesNuevos: widget.repositorioBandeja.nuevos(),
        onVerPagos: () => _ir(SeccionPanel.pagos),
        onVerReportes: () => _ir(SeccionPanel.reportes),
        ahora: widget.ahora,
      ),
      SeccionPanel.estudiantes => switch (_fichaUid) {
        final uid? => FichaEstudiantePage(
          key: ValueKey(uid),
          uid: uid,
          repositorio: widget.repositorioEstudiantes,
          onVolver: () => setState(() => _fichaUid = null),
          pagos: widget.repositorioPagos,
          ahora: widget.ahora,
        ),
        null => EstudiantesPage(
          key: ValueKey(_visita),
          repositorio: widget.repositorioEstudiantes,
          filtroInicial: _filtro,
          onAbrir: _abrirEstudiante,
          ahora: widget.ahora,
        ),
      },
      SeccionPanel.pagos => PagosPage(
        pagos: widget.repositorioPagos,
        academia: widget.repositorioAcademia,
        onAbrirEstudiante: _abrirEstudiante,
        ahora: widget.ahora,
      ),
      SeccionPanel.cupones => CuponesPage(
        repositorio: widget.repositorioAcademia,
        ahora: widget.ahora,
      ),
      SeccionPanel.versiones => VersionesPage(
        versiones: widget.repositorioVersiones,
        estudiantes: widget.repositorioEstudiantes,
        onVerEstudiantes: () => _ir(SeccionPanel.estudiantes),
        ahora: widget.ahora,
      ),
      SeccionPanel.contenido => ContenidoPage(
        key: ValueKey(_visita),
        contenido: widget.repositorioContenido,
        estudiantes: widget.repositorioEstudiantes,
        generador: widget.generadorQuiz,
        versionInicial: _destino?.$1,
        temaInicial: _destino?.$2,
      ),
      SeccionPanel.examenes => ExamenesAdminPage(
        key: ValueKey(_visita),
        repositorio: widget.repositorioExamenes,
        examenInicial: _destino?.$1,
        preguntaInicial: _destino?.$2,
      ),
      SeccionPanel.semanales => ExamenesAdminPage(
        key: const ValueKey('semanales'),
        repositorio: widget.repositorioSemanales,
        versionesSemanales: widget.repositorioEstudiantes.versiones,
      ),
      SeccionPanel.ranking => RankingPage(
        semanales: widget.repositorioSemanales,
        ranking: widget.repositorioRanking,
        onAbrirEstudiante: _abrirEstudiante,
      ),
      SeccionPanel.reportes => BandejaPage(
        repositorio: widget.repositorioBandeja,
        onAbrirEstudiante: _abrirEstudiante,
        onIrPregunta: (examen, pregunta) =>
            _irA(SeccionPanel.examenes, (examen, pregunta)),
        onIrTema: (version, tema) =>
            _irA(SeccionPanel.contenido, (version, tema)),
        ahora: widget.ahora,
      ),
      SeccionPanel.configuracion => ConfiguracionPage(
        academia: widget.repositorioAcademia,
        estudiantes: widget.repositorioEstudiantes,
        ahora: widget.ahora,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        // Sin esto, una página corta queda centrada en vertical (con un
        // hueco arriba); así siempre empieza arriba.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuLateral(
            seccion: _seccion,
            onIr: _ir,
            correo: widget.correo,
            onSalir: widget.onSalir,
            pendientes: _pendientes,
            reportesNuevos: _reportesNuevos,
          ),
          // Al cambiar de sección (o abrir una ficha), la página nueva entra
          // con un fundido en vez de aparecer de golpe.
          Expanded(
            child: AnimatedSwitcher(
              duration: duracionAnimacion(
                context,
                const Duration(milliseconds: 320),
              ),
              layoutBuilder: (actual, anteriores) => Stack(
                fit: StackFit.expand,
                children: [...anteriores, ?actual],
              ),
              child: KeyedSubtree(
                key: ValueKey('$_seccion-$_fichaUid-$_visita'),
                child: _pagina(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  final SeccionPanel seccion;
  final ValueChanged<SeccionPanel> onIr;
  final String correo;
  final VoidCallback onSalir;
  final Stream<int> pendientes;
  final Stream<int> reportesNuevos;

  const _MenuLateral({
    required this.seccion,
    required this.onIr,
    required this.correo,
    required this.onSalir,
    required this.pendientes,
    required this.reportesNuevos,
  });

  static const _grupos = [
    (
      'GENERAL',
      [
        (SeccionPanel.resumen, 'Resumen', Icons.home_outlined),
        (SeccionPanel.analitica, 'Analítica', Icons.insights_outlined),
      ],
    ),
    (
      'ESTUDIANTES',
      [
        (SeccionPanel.estudiantes, 'Estudiantes', Icons.group_outlined),
        (SeccionPanel.pagos, 'Pagos', Icons.receipt_long_outlined),
        (SeccionPanel.cupones, 'Cupones y becas', Icons.sell_outlined),
        (
          SeccionPanel.versiones,
          'Versiones y matrículas',
          Icons.layers_outlined,
        ),
        (SeccionPanel.ranking, 'Ranking semanal', Icons.emoji_events_outlined),
        (SeccionPanel.avisos, 'Avisos', Icons.campaign_outlined),
      ],
    ),
    (
      'CONTENIDO',
      [
        (SeccionPanel.contenido, 'Cursos y temas', Icons.menu_book_outlined),
        (SeccionPanel.examenes, 'Exámenes pasados', Icons.assignment_outlined),
        (
          SeccionPanel.semanales,
          'Exámenes semanales',
          Icons.event_note_outlined,
        ),
      ],
    ),
    (
      'SISTEMA',
      [
        (SeccionPanel.reportes, 'Reportes de la app', Icons.outlined_flag),
        (
          SeccionPanel.estado,
          'Estado del sistema',
          Icons.monitor_heart_outlined,
        ),
        (SeccionPanel.configuracion, 'Configuración', Icons.settings_outlined),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: p.barra,
        border: const Border(right: BorderSide(color: PaletaPanel.borde)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const LogoPuntos(),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AcademiApp',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Panel de control',
                      style: TextStyle(color: p.tenue, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final (grupo, items) in _grupos) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                    child: Text(
                      grupo,
                      style: TextStyle(
                        color: p.tenue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  for (final (s, etiqueta, icono) in items)
                    _ItemMenu(
                      etiqueta: etiqueta,
                      icono: icono,
                      activo: s == seccion,
                      onTap: () => onIr(s),
                      contador: switch (s) {
                        SeccionPanel.pagos => pendientes,
                        SeccionPanel.reportes => reportesNuevos,
                        _ => null,
                      },
                    ),
                ],
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: p.acento,
                  child: Text(
                    correo.isEmpty ? '?' : correo[0].toUpperCase(),
                    style: TextStyle(
                      color: p.sobreAcento,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombreDesdeCorreo(correo),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Administrador',
                        style: TextStyle(color: p.tenue, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Salir ($correo)',
                  onPressed: onSalir,
                  icon: Icon(Icons.logout, size: 19, color: p.apagado),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  /// Número en vivo a la derecha (p. ej. pagos por revisar).
  final Stream<int>? contador;

  const _ItemMenu({
    required this.etiqueta,
    required this.icono,
    required this.activo,
    required this.onTap,
    this.contador,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final color = activo ? p.texto : p.apagado;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: activo ? const Color(0x14FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icono, size: 19, color: activo ? p.acento : color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: TextStyle(
                      color: color,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (contador case final numeros?)
                  StreamBuilder<int>(
                    stream: numeros,
                    builder: (context, s) {
                      final n = s.data ?? 0;
                      if (n == 0) return const SizedBox.shrink();
                      return Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.acento,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          '$n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.sobreAcento,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
