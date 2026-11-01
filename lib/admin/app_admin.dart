import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app/tema_app.dart';
import 'acceso/puerta_admin.dart';
import 'examenes/repositorio_examenes_admin_firestore.dart';
import 'shell_admin.dart';

class AppAdmin extends StatelessWidget {
  const AppAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp · Panel',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: PuertaAdmin(
        acceso: AccesoAdminFirebase(FirebaseAuth.instance),
        panel: (correo, salir) => ShellAdmin(
          correo: correo,
          onSalir: salir,
          repositorioExamenes: RepositorioExamenesAdminFirestore(),
        ),
      ),
    );
  }
}
