import 'package:flutter/material.dart';

import '../core/presentation/colores_app.dart';
import 'examenes/examenes_admin_page.dart';
import 'examenes/repositorio_examenes_admin.dart';

/// Estructura del panel: menú lateral y la sección elegida.
/// Las demás secciones (material, estudiantes, seminarios) se agregan
/// aquí en los siguientes bloques.
class ShellAdmin extends StatefulWidget {
  final String correo;
  final VoidCallback onSalir;
  final RepositorioExamenesAdmin repositorioExamenes;

  const ShellAdmin({
    super.key,
    required this.correo,
    required this.onSalir,
    required this.repositorioExamenes,
  });

  @override
  State<ShellAdmin> createState() => _ShellAdminState();
}

class _ShellAdminState extends State<ShellAdmin> {
  static const _proximas = [
    ('Material', Icons.menu_book_outlined),
    ('Estudiantes', Icons.group_outlined),
    ('Seminarios', Icons.live_tv_outlined),
  ];

  int _seccion = 0;

  @override
  Widget build(BuildContext context) {
    final secciones = [
      (
        etiqueta: 'Exámenes',
        icono: Icons.assignment_outlined,
        pagina: ExamenesAdminPage(repositorio: widget.repositorioExamenes),
      ),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: ColoresApp.barra,
            selectedIndex: _seccion,
            onDestinationSelected: (i) => setState(() => _seccion = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Panel',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Salir (${widget.correo})',
                    onPressed: widget.onSalir,
                    icon: const Icon(Icons.logout),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final s in secciones)
                NavigationRailDestination(
                  icon: Icon(s.icono),
                  label: Text(s.etiqueta),
                ),
              // Próximos bloques del panel (todavía deshabilitados).
              for (final (etiqueta, icono) in _proximas)
                NavigationRailDestination(
                  icon: Icon(icono),
                  label: Text(etiqueta),
                  disabled: true,
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: secciones[_seccion].pagina),
        ],
      ),
    );
  }
}
