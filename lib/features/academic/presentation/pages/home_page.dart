import 'package:flutter/material.dart';

import '../../../enrollment/domain/entities/matricula.dart';

class HomePage extends StatelessWidget {
  final Matricula matricula;

  const HomePage({super.key, required this.matricula});

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
            const Text('Matrícula activa ✓', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Versión académica: ${matricula.versionId}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
