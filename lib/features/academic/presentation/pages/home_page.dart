import 'package:flutter/material.dart';

import '../../../enrollment/domain/entities/matricula.dart';
import '../../domain/entities/version_academica.dart';

class HomePage extends StatelessWidget {
  final Matricula matricula;
  final VersionAcademica versionAcademica;

  const HomePage({
    super.key,
    required this.matricula,
    required this.versionAcademica,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AcademiApp V2',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Matrícula activa', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Versión: ${versionAcademica.nombre}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Código: ${versionAcademica.codigo}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Estado: ${versionAcademica.estado.name}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
