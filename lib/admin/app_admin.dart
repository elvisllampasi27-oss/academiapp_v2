import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'acceso/puerta_admin.dart';
import 'avisos/repositorio_avisos_admin.dart';
import 'bandeja/repositorio_bandeja.dart';
import 'contenido/repositorio_contenido_admin_firestore.dart';
import 'estudiantes/repositorio_estudiantes_admin_firestore.dart';
import 'examenes/repositorio_examenes_admin_firestore.dart';
import 'pagos/repositorio_pagos_admin_firestore.dart';
import 'shell_admin.dart';
import 'sistema/sonda_sistema.dart';
import 'tema_panel.dart';
import 'versiones/repositorio_versiones_admin_firestore.dart';

/// Composición del panel: aquí se eligen las implementaciones (Firebase).
class AppAdmin extends StatefulWidget {
  const AppAdmin({super.key});

  @override
  State<AppAdmin> createState() => _AppAdminState();
}

class _AppAdminState extends State<AppAdmin> {
  final _estudiantes = RepositorioEstudiantesAdminFirestore();
  final _examenes = RepositorioExamenesAdminFirestore();
  final _pagos = RepositorioPagosAdminFirestore();
  final _versiones = RepositorioVersionesAdminFirestore();
  final _contenido = RepositorioContenidoAdminFirestore();
  final _generador = GeneradorQuizFunctions();
  final _bandeja = RepositorioBandejaFirestore();
  final _avisos = RepositorioAvisosAdminFirestore();
  final _sonda = SondaSistemaFirebase();

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
          repositorioPagos: _pagos,
          repositorioAcademia: _pagos,
          repositorioVersiones: _versiones,
          repositorioContenido: _contenido,
          generadorQuiz: _generador,
          repositorioBandeja: _bandeja,
          repositorioAvisos: _avisos,
          sondaSistema: _sonda,
        ),
      ),
    );
  }
}
