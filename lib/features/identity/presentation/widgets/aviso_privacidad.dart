import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/enlaces.dart';
import '../../../../core/presentation/colores_app.dart';
import 'estilo_autenticacion.dart';

/// Abre la política de privacidad en el navegador.
void abrirPoliticaPrivacidad() {
  launchUrl(
    Uri.parse(enlacePoliticaPrivacidad),
    mode: LaunchMode.externalApplication,
  );
}

/// "Al crear tu cuenta aceptas la política de privacidad", con el enlace.
class AvisoPrivacidad extends StatelessWidget {
  /// Cómo empieza la frase: "Al crear tu cuenta", "Al continuar"...
  final String accion;

  const AvisoPrivacidad({super.key, this.accion = 'Al crear tu cuenta'});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$accion aceptas la',
          style: const TextStyle(color: ColoresApp.apagado, fontSize: 12),
        ),
        const EnlaceTexto(
          texto: 'política de privacidad',
          resaltado: true,
          alPresionar: abrirPoliticaPrivacidad,
        ),
      ],
    );
  }
}
