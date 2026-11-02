import 'package:flutter/material.dart';

import 'estudiantes/estudiantes_page.dart';
import 'estudiantes/ficha_estudiante_page.dart';
import 'estudiantes/modelo_estudiantes.dart';
import 'estudiantes/repositorio_estudiantes_admin.dart';
import 'examenes/examenes_admin_page.dart';
import 'examenes/repositorio_examenes_admin.dart';
import 'logo_puntos.dart';
import 'resumen/resumen_page.dart';
import 'tema_panel.dart';
import 'widgets_panel.dart';

enum SeccionPanel { resumen, estudiantes, examenes }

/// Estructura del panel: menú lateral por grupos y la sección elegida.
/// Las secciones de los siguientes bloques (pagos, versiones, contenido…)
/// se agregan aquí.
class ShellAdmin extends StatefulWidget {
  final String correo;
  final VoidCallback onSalir;
  final RepositorioEstudiantesAdmin repositorioEstudiantes;
  final RepositorioExamenesAdmin repositorioExamenes;
  final DateTime Function() ahora;

  const ShellAdmin({
    super.key,
    required this.correo,
    required this.onSalir,
    required this.repositorioEstudiantes,
    required this.repositorioExamenes,
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

  void _ir(SeccionPanel s) => setState(() {
    _seccion = s;
    _fichaUid = null;
    _filtro = FiltroEstudiantes.todos;
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
        correoAdmin: widget.correo,
        ahora: widget.ahora,
      ),
      SeccionPanel.estudiantes => switch (_fichaUid) {
        final uid? => FichaEstudiantePage(
          key: ValueKey(uid),
          uid: uid,
          repositorio: widget.repositorioEstudiantes,
          onVolver: () => setState(() => _fichaUid = null),
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
      SeccionPanel.examenes => ExamenesAdminPage(
        repositorio: widget.repositorioExamenes,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _MenuLateral(
            seccion: _seccion,
            onIr: _ir,
            correo: widget.correo,
            onSalir: widget.onSalir,
          ),
          Expanded(child: _pagina()),
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

  const _MenuLateral({
    required this.seccion,
    required this.onIr,
    required this.correo,
    required this.onSalir,
  });

  static const _grupos = [
    ('GENERAL', [(SeccionPanel.resumen, 'Resumen', Icons.home_outlined)]),
    (
      'ESTUDIANTES',
      [(SeccionPanel.estudiantes, 'Estudiantes', Icons.group_outlined)],
    ),
    (
      'CONTENIDO',
      [(SeccionPanel.examenes, 'Exámenes', Icons.assignment_outlined)],
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
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
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

  const _ItemMenu({
    required this.etiqueta,
    required this.icono,
    required this.activo,
    required this.onTap,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icono, size: 19, color: activo ? p.acento : color),
                const SizedBox(width: 12),
                Text(
                  etiqueta,
                  style: TextStyle(
                    color: color,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
