import 'package:flutter/material.dart';

import 'dependencias.dart';
import 'puerta_sesion_page.dart';
import 'tema_app.dart';

class AcademiApp extends StatelessWidget {
  final Dependencias dependencias;

  const AcademiApp({super.key, required this.dependencias});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: PuertaSesionPage(dependencias: dependencias),
    );
  }
}
