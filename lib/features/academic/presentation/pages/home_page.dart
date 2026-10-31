import 'package:flutter/material.dart';

import '../../../enrollment/domain/entities/matricula.dart';
import '../../domain/entities/contexto_dia_estudiante.dart';
import '../../domain/entities/curso.dart';
import '../../domain/entities/tema.dart';
import '../../domain/entities/version_academica.dart';

class HomePage extends StatelessWidget {
  final Matricula matricula;
  final VersionAcademica versionAcademica;
  final ContextoDiaEstudiante diaEstudiante;
  final VoidCallback? onCerrarSesion;
  final void Function(Tema tema, Curso? curso)? onAbrirTema;
  final VoidCallback? onAbrirMiRuta;

  const HomePage({
    super.key,
    required this.matricula,
    required this.versionAcademica,
    required this.diaEstudiante,
    this.onCerrarSesion,
    this.onAbrirTema,
    this.onAbrirMiRuta,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AcademiApp V2'),
        actions: [
          if (onAbrirMiRuta != null)
            IconButton(
              tooltip: 'Mi Ruta',
              icon: const Icon(Icons.route),
              onPressed: onAbrirMiRuta,
            ),
          if (onCerrarSesion != null)
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: onCerrarSesion,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            versionAcademica.nombre,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(diaEstudiante.plan.nombre, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          if (diaEstudiante.dia == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Hoy no tienes actividades académicas.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else ...[
            Text(
              'Día académico ${diaEstudiante.dia!.numero}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Actividades de hoy'),
            const SizedBox(height: 16),
            if (diaEstudiante.actividades.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Las actividades de hoy todavía no han sido publicadas.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              )
            else
              ...diaEstudiante.actividades.map((actividad) {
                final tema = _buscarTema(actividad.temaId);
                final curso = tema == null ? null : _buscarCurso(tema.cursoId);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${actividad.orden}')),
                    title: Text(tema?.titulo ?? 'Tema no encontrado'),
                    subtitle: Text(curso?.nombre ?? 'Curso no encontrado'),
                    trailing: tema == null || onAbrirTema == null
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: tema == null || onAbrirTema == null
                        ? null
                        : () => onAbrirTema!(tema, curso),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Tema? _buscarTema(String temaId) {
    for (final tema in diaEstudiante.temas) {
      if (tema.id == temaId) {
        return tema;
      }
    }

    return null;
  }

  Curso? _buscarCurso(String cursoId) {
    for (final curso in diaEstudiante.cursos) {
      if (curso.id == cursoId) {
        return curso;
      }
    }

    return null;
  }
}
