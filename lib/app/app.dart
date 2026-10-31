import 'package:flutter/material.dart';

import '../features/identity/infrastructure/repositories/repositorio_usuario_firestore.dart';
import '../features/identity/infrastructure/services/firebase_servicio_autenticacion.dart';
import '../features/identity/presentation/pages/puerta_sesion_page.dart';
import 'tema_app.dart';

class AcademiApp extends StatelessWidget {
  const AcademiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final servicioAutenticacion = FirebaseServicioAutenticacion();
    final repositorioUsuario = RepositorioUsuarioFirestore();

    return MaterialApp(
      title: 'AcademiApp',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: PuertaSesionPage(
        servicioAutenticacion: servicioAutenticacion,
        servicioRecuperacion: servicioAutenticacion,
        servicioGoogle: servicioAutenticacion,
        repositorioUsuario: repositorioUsuario,
      ),
    );
  }
}
