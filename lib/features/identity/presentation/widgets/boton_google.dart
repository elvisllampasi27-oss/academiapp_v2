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
      height: 52,
      child: OutlinedButton(
        onPressed: cargando ? null : alPresionar,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x47FFFFFF)),
          shape: const StadiumBorder(),
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
                  const Flexible(
                    child: Text(
                      'Continuar con Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
