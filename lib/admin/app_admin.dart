import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'acceso/puerta_admin.dart';
import 'estudiantes/repositorio_estudiantes_admin_firestore.dart';
import 'examenes/repositorio_examenes_admin_firestore.dart';
import 'shell_admin.dart';
import 'tema_panel.dart';

/// Composición del panel: aquí se eligen las implementaciones (Firebase).
class AppAdmin extends StatefulWidget {
  const AppAdmin({super.key});

  @override
  State<AppAdmin> createState() => _AppAdminState();
}

class _AppAdminState extends State<AppAdmin> {
  final _estudiantes = RepositorioEstudiantesAdminFirestore();
  final _examenes = RepositorioExamenesAdminFirestore();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp · Panel',
      debugShowCheckedModeBanner: false,
      theme: temaPanel(),
      home: PuertaAdmin(
        acceso: AccesoAdminFirebase(FirebaseAuth.instance),
        panel: (correo, salir) => ShellAdmin(
          correo: correo,
          onSalir: salir,
          repositorioEstudiantes: _estudiantes,
          repositorioExamenes: _examenes,
        ),
      ),
    );
  }
}
