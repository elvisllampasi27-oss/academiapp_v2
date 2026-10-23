import 'package:flutter/material.dart';

import '../../domain/services/iniciar_sesion_estudiante_service.dart';

class LoginPage extends StatefulWidget {
  final IniciarSesionEstudianteService iniciarSesionService;
  final VoidCallback onSesionIniciada;

  const LoginPage({
    super.key,
    required this.iniciarSesionService,
    required this.onSesionIniciada,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final correoController = TextEditingController();
  final contrasenaController = TextEditingController();

  bool cargando = false;
  String? error;

  @override
  void dispose() {
    correoController.dispose();
    contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final correo = correoController.text.trim();
    final contrasena = contrasenaController.text;

    if (correo.isEmpty) {
      setState(() {
        error = 'Ingresa tu correo.';
      });
      return;
    }

    if (!correo.contains('@')) {
      setState(() {
        error = 'Ingresa un correo válido.';
      });
      return;
    }

    if (contrasena.isEmpty) {
      setState(() {
        error = 'Ingresa tu contraseña.';
      });
      return;
    }

    setState(() {
      cargando = true;
      error = null;
    });

    try {
      await widget.iniciarSesionService.iniciarSesion(
        correo: correo,
        contrasena: contrasena,
      );

      if (!mounted) return;

      widget.onSesionIniciada();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error = 'Correo o contraseña incorrectos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AcademiApp',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contrasenaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              const SizedBox(height: 24),
              if (error != null) ...[Text(error!), const SizedBox(height: 16)],
              FilledButton(
                onPressed: cargando ? null : _iniciarSesion,
                child: Text(cargando ? 'Ingresando...' : 'Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
