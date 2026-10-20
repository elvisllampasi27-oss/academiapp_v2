import 'package:flutter/material.dart';

import '../features/academic/presentation/pages/home_page.dart';

class AcademiApp extends StatelessWidget {
  const AcademiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'AcademiApp',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
