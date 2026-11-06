import 'package:flutter/material.dart';

import '../../../../core/presentation/colores_app.dart';
import '../../domain/entities/usuario_academiapp.dart';
import '../../../../core/presentation/animaciones.dart';

class PerfilPage extends StatelessWidget {
  final UsuarioAcademiApp usuario;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onAbrirSeminarios;
  final VoidCallback? onAbrirPremium;
  final VoidCallback? onReportar;
  final VoidCallback? onMisReportes;

  const PerfilPage({
    super.key,
    required this.usuario,
    required this.onCerrarSesion,
    this.onAbrirSeminarios,
    this.onAbrirPremium,
    this.onReportar,
    this.onMisReportes,
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
          if (onAbrirSeminarios != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.live_tv_outlined),
                title: const Text('Seminarios en vivo'),
                subtitle: const Text('Repasos por YouTube y sus grabaciones'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onAbrirSeminarios,
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
