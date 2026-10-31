import 'dart:ui';

import 'package:flutter/material.dart';

/// Componentes visuales de las pantallas de acceso: "vidrio 2.0".
/// Solo aquí se usa desenfoque (pantallas de entrada); dentro de la app los
/// paneles son planos para que los celulares de gama baja vayan fluidos.

const _bordeVidrio = Color(0x47FFFFFF);
const _bordeCampo = Color(0x38FFFFFF);
const _rellenoCampo = Color(0x14FFFFFF);
const _rellenoVentana = Color(0x99000000);
const _textoSuave = Color(0xFFD4D4D8);
const _desenfoque = 20.0;

/// Relleno del vidrio: más claro arriba a la izquierda, como luz que entra.
const _degradadoVidrio = LinearGradient(
  begin: Alignment(-0.6, -1),
  end: Alignment(0.6, 1),
  colors: [Color(0x33FFFFFF), Color(0x12FFFFFF), Color(0x08FFFFFF)],
  stops: [0, 0.45, 1],
);

const _degradadoVidrioSuave = LinearGradient(
  begin: Alignment(-0.6, -1),
  end: Alignment(0.6, 1),
  colors: [Color(0x1FFFFFFF), Color(0x05FFFFFF)],
);

/// Vidrio con desenfoque, borde claro, brillo en el canto superior y sombra.
class Vidrio extends StatelessWidget {
  final Widget child;
  final BorderRadius radio;
  final EdgeInsetsGeometry? padding;
  final bool suave;

  const Vidrio({
    super.key,
    required this.child,
    required this.radio,
    this.padding,
    this.suave = false,
  });

  @override
  Widget build(BuildContext context) {
    final desenfoque = suave ? 8.0 : _desenfoque;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: suave
            ? null
            : const [
                BoxShadow(
                  color: Color(0x73000000),
                  blurRadius: 60,
                  offset: Offset(0, 24),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: radio,
                  gradient: suave ? _degradadoVidrioSuave : _degradadoVidrio,
                  border: Border.all(
                    color: suave ? const Color(0x29FFFFFF) : _bordeVidrio,
                  ),
                ),
                child: child,
              ),
              if (!suave)
                // Brillo del canto superior (el "inset" del diseño).
                const Positioned(
                  left: 18,
                  right: 18,
                  top: 0,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x73FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          const ColoredBox(color: Color(0x8C050609)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
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

/// Barra superior: volver (si hay) y la marca al centro.
class BarraAutenticacion extends StatelessWidget {
  final VoidCallback? alVolver;

  const BarraAutenticacion({super.key, this.alVolver});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: alVolver == null
              ? null
              : Vidrio(
                  suave: true,
                  radio: BorderRadius.circular(22),
                  child: IconButton(
                    tooltip: 'Volver',
                    color: Colors.white,
                    iconSize: 20,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: alVolver,
                  ),
                ),
        ),
        const Expanded(
          child: Text(
            'AcademiApp',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
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
            fontSize: 32,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: const TextStyle(fontSize: 14, color: _textoSuave),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Tarjeta principal de vidrio. Con [capaTrasera] muestra una segunda hoja
/// detrás, asomando por arriba (profundidad del diseño).
class TarjetaVidrio extends StatelessWidget {
  final Widget child;
  final bool capaTrasera;

  const TarjetaVidrio({
    super.key,
    required this.child,
    this.capaTrasera = false,
  });

  @override
  Widget build(BuildContext context) {
    final tarjeta = Vidrio(
      radio: BorderRadius.circular(30),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: child,
    );

    if (!capaTrasera) return tarjeta;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 22,
            right: 22,
            top: -14,
            bottom: 14,
            child: Vidrio(
              suave: true,
              radio: BorderRadius.circular(30),
              child: const SizedBox.expand(),
            ),
          ),
          tarjeta,
        ],
      ),
    );
  }
}

class CampoVidrio extends StatefulWidget {
  final String hint;

  /// Texto encima del campo (p. ej. "Correo").
  final String? etiqueta;
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
    this.etiqueta,
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
    final campo = Container(
      decoration: BoxDecoration(
        color: _rellenoCampo,
        border: Border.all(color: _bordeCampo),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.esContrasena && _oculto,
        keyboardType: widget.tipoTeclado,
        textInputAction: widget.accion,
        autofillHints: widget.autocompletado,
        onSubmitted: widget.alEnviar,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          suffixIcon: widget.esContrasena
              ? IconButton(
                  tooltip: _oculto
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _oculto ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _oculto = !_oculto),
                )
              : null,
        ),
      ),
    );

    final etiqueta = widget.etiqueta;
    if (etiqueta == null) return campo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 13, color: Color(0xFFE4E4E7)),
        ),
        const SizedBox(height: 6),
        campo,
      ],
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
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrir(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: _rellenoCampo,
            border: Border.all(color: _bordeCampo),
            borderRadius: BorderRadius.circular(16),
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

  /// Botón sólido claro (acción principal) en lugar de vidrio.
  final bool principal;

  const BotonVidrio({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.cargando = false,
    this.principal = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = principal ? const Color(0xFF0B0C10) : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: cargando ? null : alPresionar,
        style: ElevatedButton.styleFrom(
          backgroundColor: principal
              ? const Color(0xFFF4F4F5)
              : Colors.white.withValues(alpha: 0.08),
          disabledBackgroundColor: principal
              ? const Color(0xB3F4F4F5)
              : Colors.white.withValues(alpha: 0.05),
          foregroundColor: colorTexto,
          disabledForegroundColor: colorTexto,
          elevation: principal ? 6 : 0,
          shadowColor: Colors.black,
          shape: StadiumBorder(
            side: principal
                ? BorderSide.none
                : const BorderSide(color: _bordeVidrio),
          ),
        ),
        child: cargando
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorTexto,
                ),
              )
            : Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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
        color: const Color(0x2EFF8A5B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x8CFF8A5B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFFB59A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Color(0xFFFFE1D6), fontSize: 13),
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
      child: Divider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
    );

    return Row(
      children: [
        linea,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: const TextStyle(color: _textoSuave, fontSize: 13),
          ),
        ),
        linea,
      ],
    );
  }
}

class EnlaceTexto extends StatelessWidget {
  final String texto;
  final VoidCallback? alPresionar;
  final bool resaltado;

  const EnlaceTexto({
    super.key,
    required this.texto,
    required this.alPresionar,
    this.resaltado = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: alPresionar,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        minimumSize: const Size(44, 40),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
          color: resaltado ? Colors.white : const Color(0xFFE4E4E7),
          fontSize: 13,
        ),
      ),
    );
  }
}

/// "¿No tienes cuenta? Crear cuenta": pregunta y enlace en una línea.
class PreguntaConEnlace extends StatelessWidget {
  final String pregunta;
  final String enlace;
  final VoidCallback? alPresionar;

  const PreguntaConEnlace({
    super.key,
    required this.pregunta,
    required this.enlace,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap: en pantallas angostas el enlace baja de línea en vez de cortarse.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          pregunta,
          style: const TextStyle(color: _textoSuave, fontSize: 14),
        ),
        EnlaceTexto(texto: enlace, alPresionar: alPresionar, resaltado: true),
      ],
    );
  }
}
