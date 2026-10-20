import 'package:flutter/material.dart';

class AcademiApp extends StatelessWidget {
  const AcademiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcademiApp',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text(
            'AcademiApp V2',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}