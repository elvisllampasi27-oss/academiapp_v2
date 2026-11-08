import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/usuario_academiapp.dart';
import '../../../../core/presentation/animaciones.dart';
import '../../../student_model/domain/entities/actividad_alumno.dart';
import '../../../student_model/presentation/mapa_actividad.dart';

class PerfilPage extends StatelessWidget {
  final UsuarioAcademiApp usuario;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onAbrirPremium;
  final VoidCallback? onReportar;
  final VoidCallback? onMisReportes;

  /// Actividad del alumno en su matrícula (el mapa de cuadritos).
  final ActividadAlumno? actividad;

  const PerfilPage({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
    this.onAbrirPremium,
    this.onReportar,
    this.onMisReportes,
    this.actividad,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = usuario.nombre.trim().isEmpty
        ? '?'
        : usuario.nombre.trim()[0].toUpperCase();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: enCascada([
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColoresApp.panel,
                  border: Border.all(color: ColoresApp.borde),
                ),
                child: Text(
                  inicial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.carreraPostulada ?? usuario.correo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColoresApp.apagado,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (actividad case final actividad?) ...[
            MapaActividad(actividad: actividad),
            const SizedBox(height: 16),
          ],
          if (onAbrirPremium != null)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.workspace_premium,
                  color: ColoresApp.ambar,
                ),
                title: const Text('Premium'),
                subtitle: const Text('Tu plan, beneficios y pagos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onAbrirPremium,
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Correo'),
              subtitle: Text(usuario.correo),
            ),
          ),
          if (onReportar != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.outlined_flag),
                title: const Text('Reportar un problema'),
                subtitle: const Text('Algo no funciona o está mal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onReportar,
              ),
            ),
          if (onMisReportes != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Mis reportes'),
                subtitle: const Text('Su estado y la respuesta del equipo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onMisReportes,
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onCerrarSesion,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              style: TextButton.styleFrom(foregroundColor: ColoresApp.apagado),
            ),
          ),
        ]),
      ),
    );
  }
}
