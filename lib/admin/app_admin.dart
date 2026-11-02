import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _clavePaleta = 'panel.paleta';

  final _estudiantes = RepositorioEstudiantesAdminFirestore();
  final _examenes = RepositorioExamenesAdminFirestore();
  PaletaPanel _paleta = PaletaPanel.marino;

  @override
  void initState() {
    super.initState();
    _leerPaleta();
  }

  Future<void> _leerPaleta() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final id = preferencias.getString(_clavePaleta);
      if (mounted) setState(() => _paleta = PaletaPanel.porId(id));
    } catch (_) {
      // Sin almacenamiento local: se queda la paleta por defecto.
    }
  }

  Future<void> _cambiarPaleta(PaletaPanel paleta) async {
    setState(() => _paleta = paleta);
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(_clavePaleta, paleta.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp · Panel',
      debugShowCheckedModeBanner: false,
      theme: temaPanel(_paleta),
      home: PuertaAdmin(
        acceso: AccesoAdminFirebase(FirebaseAuth.instance),
        panel: (correo, salir) => ShellAdmin(
          correo: correo,
          onSalir: salir,
          repositorioEstudiantes: _estudiantes,
          repositorioExamenes: _examenes,
          paleta: _paleta,
          onPaleta: _cambiarPaleta,
        ),
      ),
    );
  }
}
