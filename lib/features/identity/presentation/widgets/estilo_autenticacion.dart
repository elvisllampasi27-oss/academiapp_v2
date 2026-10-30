import 'dart:ui';

import 'package:flutter/material.dart';

/// Componentes visuales de las pantallas de acceso.
/// Estilo "glass" reutilizado de AcademiApp V1 (login.dart / singup.dart).

const _bordeVidrio = Color(0x99FFFFFF);
// Paleta neutra: solo blanco y negro translúcidos sobre la foto.
const _rellenoTarjeta = Color(0x1AFFFFFF);
const _rellenoVentana = Color(0x99000000);
const _desenfoque = 12.0;

class FondoAutenticacion extends StatelessWidget {
  final Widget child;

  const FondoAutenticacion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/fondo_autenticacion.jpeg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xAA000000),
                  Color(0x33000000),
                  Color(0x99000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EncabezadoAutenticacion extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const EncabezadoAutenticacion({
    super.key,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class TarjetaVidrio extends StatelessWidget {
  final Widget child;

  const TarjetaVidrio({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _desenfoque, sigmaY: _desenfoque),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _rellenoTarjeta,
            border: Border.all(color: _bordeVidrio, width: 0.6),
          ),
          child: child,
        ),
      ),
    );
  }
}

class CampoVidrio extends StatefulWidget {
  final String hint;
  final TextEditingController controller;
  final bool esContrasena;
  final TextInputType? tipoTeclado;
  final TextInputAction? accion;
  final Iterable<String>? autocompletado;
  final ValueChanged<String>? alEnviar;

  const CampoVidrio({
    super.key,
    required this.hint,
    required this.controller,
    this.esContrasena = false,
    this.tipoTeclado,
    this.accion,
    this.autocompletado,
    this.alEnviar,
  });

  @override
  State<CampoVidrio> createState() => _CampoVidrioState();
}

class _CampoVidrioState extends State<CampoVidrio> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _bordeVidrio, width: 0.6),
        borderRadius: BorderRadius.circular(9),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.esContrasena && _oculto,
        keyboardType: widget.tipoTeclado,
        textInputAction: widget.accion,
        autofillHints: widget.autocompletado,
        onSubmitted: widget.alEnviar,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          suffixIcon: widget.esContrasena
              ? IconButton(
                  tooltip: _oculto
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _oculto ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _oculto = !_oculto),
                )
              : null,
        ),
      ),
    );
  }
}

/// Campo de selección con estilo vidrio. Al tocarlo abre una ventana
/// centrada translúcida (no el menú opaco por defecto de Flutter) con buscador.
class SelectorVidrio extends StatelessWidget {
  final String hint;
  final String? valor;
  final List<String> opciones;
  final ValueChanged<String?> alCambiar;

  const SelectorVidrio({
    super.key,
    required this.hint,
    required this.valor,
    required this.opciones,
    required this.alCambiar,
  });

  Future<void> _abrir(BuildContext context) async {
    final elegido = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _HojaSeleccionVidrio(
            titulo: hint,
            opciones: opciones,
            seleccionado: valor,
          ),
        ),
      ),
    );

    if (elegido != null) {
      alCambiar(elegido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneValor = valor != null;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => _abrir(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: _bordeVidrio, width: 0.6),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  valor ?? hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: tieneValor
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaSeleccionVidrio extends StatefulWidget {
  final String titulo;
  final List<String> opciones;
  final String? seleccionado;

  const _HojaSeleccionVidrio({
    required this.titulo,
    required this.opciones,
    required this.seleccionado,
  });

  @override
  State<_HojaSeleccionVidrio> createState() => _HojaSeleccionVidrioState();
}

class _HojaSeleccionVidrioState extends State<_HojaSeleccionVidrio> {
  final _busquedaController = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  static String _normalizar(String texto) {
    const conTilde = 'áéíóúüñ';
    const sinTilde = 'aeiouun';
    final minusculas = texto.toLowerCase();
    final buffer = StringBuffer();
    for (final caracter in minusculas.split('')) {
      final indice = conTilde.indexOf(caracter);
      buffer.write(indice >= 0 ? sinTilde[indice] : caracter);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final filtro = _normalizar(_filtro.trim());
    final visibles = filtro.isEmpty
        ? widget.opciones
        : widget.opciones
              .where((opcion) => _normalizar(opcion).contains(filtro))
              .toList();

    final alturaMaxima = MediaQuery.sizeOf(context).height * 0.7;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _desenfoque, sigmaY: _desenfoque),
        child: Container(
          constraints: BoxConstraints(maxHeight: alturaMaxima),
          decoration: BoxDecoration(
            color: _rellenoVentana,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _bordeVidrio, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  widget.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: _bordeVidrio, width: 0.6),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: TextField(
                    controller: _busquedaController,
                    onChanged: (texto) => setState(() => _filtro = texto),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'Buscar',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: visibles.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Sin resultados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemCount: visibles.length,
                        itemBuilder: (context, indice) {
                          final opcion = visibles[indice];
                          return _OpcionVidrio(
                            texto: opcion,
                            seleccionada: opcion == widget.seleccionado,
                            alPresionar: () =>
                                Navigator.of(context).pop(opcion),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionVidrio extends StatelessWidget {
  final String texto;
  final bool seleccionada;
  final VoidCallback alPresionar;

  const _OpcionVidrio({
    required this.texto,
    required this.seleccionada,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: alPresionar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: seleccionada
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: seleccionada
                  ? Border.all(color: _bordeVidrio, width: 0.6)
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: seleccionada
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (seleccionada)
                  const Icon(Icons.check, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BotonVidrio extends StatelessWidget {
  final String texto;
  final bool cargando;
  final VoidCallback? alPresionar;

  const BotonVidrio({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: cargando ? null : alPresionar,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: const BorderSide(color: _bordeVidrio, width: 0.6),
          ),
        ),
        child: cargando
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

class MensajeErrorVidrio extends StatelessWidget {
  final String mensaje;

  const MensajeErrorVidrio({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.6),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFB4AB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Color(0xFFFFDAD6), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class SeparadorTexto extends StatelessWidget {
  final String texto;

  const SeparadorTexto({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    final linea = Expanded(
      child: Divider(color: Colors.white.withValues(alpha: 0.5), thickness: 1),
    );

    return Row(
      children: [
        linea,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        linea,
      ],
    );
  }
}

class EnlaceTexto extends StatelessWidget {
  final String texto;
  final VoidCallback alPresionar;

  const EnlaceTexto({
    super.key,
    required this.texto,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: alPresionar,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          fontSize: 13,
        ),
      ),
    );
  }
}
