import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'acceso/puerta_admin.dart';
import 'avisos/repositorio_avisos_admin.dart';
import 'bandeja/repositorio_bandeja.dart';
import 'contenido/narraciones_admin_firestore.dart';
import 'docentes/repositorio_clases_docentes_admin.dart';
import 'docentes/repositorio_docentes_admin.dart';
import 'docentes/repositorio_en_vivos_admin.dart';
import 'contenido/repositorio_contenido_admin_firestore.dart';
import 'estudiantes/repositorio_estudiantes_admin_firestore.dart';
import 'examenes/repositorio_examenes_admin_firestore.dart';
import 'pagos/repositorio_pagos_admin_firestore.dart';
import 'ranking/ranking_admin.dart';
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
  final _semanales = RepositorioExamenesAdminFirestore(
    colecciones: ColeccionesExamen.semanales,
  );
  final _ranking = RepositorioRankingAdminFirestore();
  final _pagos = RepositorioPagosAdminFirestore();
  final _versiones = RepositorioVersionesAdminFirestore();
  final _contenido = RepositorioContenidoAdminFirestore();
  final _generador = GeneradorQuizFunctions();
  final _narraciones = RepositorioNarracionesAdminFirestore();
  final _docentes = RepositorioDocentesAdminFirestore();
  final _clasesDocentes = RepositorioClasesDocentesAdminFirestore();
  final _enVivos = RepositorioEnVivosAdminFirestore();
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
          repositorioSemanales: _semanales,
          repositorioRanking: _ranking,
          repositorioPagos: _pagos,
          repositorioAcademia: _pagos,
          repositorioVersiones: _versiones,
          repositorioContenido: _contenido,
          generadorQuiz: _generador,
          repositorioNarraciones: _narraciones,
          repositorioDocentes: _docentes,
          repositorioClasesDocentes: _clasesDocentes,
          repositorioEnVivos: _enVivos,
          repositorioBandeja: _bandeja,
          repositorioAvisos: _avisos,
          sondaSistema: _sonda,
        ),
      ),
    );
  }
}
