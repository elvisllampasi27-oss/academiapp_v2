import 'package:flutter/material.dart';

/// Botón "Continuar con Google" con el mismo estilo vidrio que el resto.
class BotonGoogle extends StatelessWidget {
  final bool cargando;
  final VoidCallback? alPresionar;

  const BotonGoogle({
    super.key,
    required this.alPresionar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: cargando ? null : alPresionar,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0x99FFFFFF), width: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: cargando
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/google.png',
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continuar con Google',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}
