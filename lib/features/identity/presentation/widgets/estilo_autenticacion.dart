import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/presentation/animaciones.dart';

/// Componentes visuales de las pantallas de acceso: "vidrio líquido" (al
/// estilo Liquid Glass). Solo aquí se usa desenfoque (pantallas de entrada);
/// dentro de la app los paneles son planos para que los celulares de gama
/// baja vayan fluidos.

const _bordeVidrio = Color(0x47FFFFFF);
const _bordeCampo = Color(0x38FFFFFF);
const _rellenoCampo = Color(0x14FFFFFF);
const _rellenoVentana = Color(0x99000000);
const _textoSuave = Color(0xFFD4D4D8);
const _desenfoque = 20.0;

/// Vidrio líquido: casi transparente (desenfoque leve y colores un poco más
/// vivos detrás), con un canto de luz que brilla más arriba a la izquierda y
/// abajo a la derecha, un reflejo suave arriba y algo de grosor abajo.
///
/// La refracción real (que deforme lo de atrás como una lente) necesita un
/// shader propio que no funciona bien en la web ni en gama baja; este es el
/// mismo aspecto sin ese costo.
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

  /// Satura un poco lo que se ve a través (los colores "se encienden").
  static const _saturar = ColorFilter.matrix(<double>[
    1.2765, -0.2503, -0.0262, 0, 0, //
    -0.0745, 1.0997, -0.0252, 0, 0, //
    -0.0745, -0.2503, 1.3248, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final desenfoque = suave ? 4.0 : 7.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: suave
            ? null
            : const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 40,
                  offset: Offset(0, 18),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: BackdropFilter(
          filter: ImageFilter.compose(
            outer: _saturar,
            inner: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque),
          ),
          child: CustomPaint(
            painter: _LuzLiquida(radio: radio, suave: suave, frente: false),
            foregroundPainter: _LuzLiquida(
              radio: radio,
              suave: suave,
              frente: true,
            ),
            child: Container(
              width: double.infinity,
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: radio,
                color: suave
                    ? const Color(0x0DFFFFFF)
                    : const Color(0x12FFFFFF),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Las luces del vidrio líquido. Detrás del contenido: el reflejo de arriba
/// y el grosor de abajo. Delante: el canto de luz.
class _LuzLiquida extends CustomPainter {
  final BorderRadius radio;
  final bool suave;
  final bool frente;

  const _LuzLiquida({
    required this.radio,
    required this.suave,
    required this.frente,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final forma = radio.toRRect(rect);

    if (!frente) {
      // Reflejo: luz que entra por arriba y se apaga hacia el medio.
      canvas.drawRRect(
        forma,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x26FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.38],
          ).createShader(rect),
      );
      // Grosor: el borde de abajo un poco más oscuro, como vidrio grueso.
      canvas.drawRRect(
        forma,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0x1F000000), Color(0x00000000)],
            stops: [0, 0.22],
          ).createShader(rect),
      );
      return;
    }

    // Canto de luz: fuerte arriba a la izquierda, casi nada a los lados y
    // un segundo brillo abajo a la derecha.
    final ancho = suave ? 1.0 : 1.4;
    canvas.drawRRect(
      forma.deflate(ancho / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ancho
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xD9FFFFFF),
            Color(0x33FFFFFF),
            Color(0x0FFFFFFF),
            Color(0x33FFFFFF),
            Color(0x99FFFFFF),
          ],
          stops: [0, 0.22, 0.5, 0.78, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LuzLiquida anterior) =>
      anterior.radio != radio ||
      anterior.suave != suave ||
      anterior.frente != frente;
}

/// Letra de las pantallas de acceso: Comic Neue (el estilo de Comic Sans,
/// con licencia libre).
const fuenteAcceso = 'ComicNeue';

/// Aplica la letra de acceso a todo lo de abajo: textos, campos y botones.
class LetraAcceso extends StatelessWidget {
  final Widget child;

  const LetraAcceso({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        textTheme: tema.textTheme.apply(fontFamily: fuenteAcceso),
        primaryTextTheme: tema.primaryTextTheme.apply(fontFamily: fuenteAcceso),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: fuenteAcceso),
        child: child,
      ),
    );
  }
}

/// El puma de AcademiApp como fondo de las pantallas de acceso: grande,
/// arriba y tenue, para que las letras se lean bien encima.
class PumaDeFondo extends StatelessWidget {
  /// Qué tan visible queda (más bajo = más tenue).
  static const opacidad = 0.4;
  static const ruta = 'assets/puma/rostro.webp';

  /// Proporción de la imagen (ancho / alto).
  static const proporcion = 659 / 624;

  const PumaDeFondo({super.key});

  /// Ancho del puma de fondo para una pantalla de [tamano].
  static double anchoPara(Size tamano) =>
      (tamano.width * 0.95).clamp(0, 520).toDouble();

  /// Centro del puma de fondo: arriba, detrás del título.
  static Offset centroPara(Size tamano) =>
      Offset(tamano.width / 2, tamano.height * 0.33);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final tamano = restricciones.biggest;
        final ancho = anchoPara(tamano);
        final centro = centroPara(tamano);
        return Stack(
          children: [
            Positioned(
              left: centro.dx - ancho / 2,
              top: centro.dy - ancho / proporcion / 2,
              width: ancho,
              // Opacidad directa en la imagen: no crea una capa aparte.
              child: const Image(
                image: AssetImage(ruta),
                fit: BoxFit.contain,
                opacity: AlwaysStoppedAnimation(opacidad),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FondoAutenticacion extends StatelessWidget {
  final Widget child;

  const FondoAutenticacion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LetraAcceso(
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PumaDeFondo(),
            const ColoredBox(color: Color(0x73050609)),
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
        EntradaDifuminada(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        EntradaDifuminada(
          retraso: const Duration(milliseconds: 100),
          child: Text(
            subtitulo,
            style: const TextStyle(fontSize: 14, color: _textoSuave),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Tarjeta principal de vidrio líquido.
class TarjetaVidrio extends StatelessWidget {
  final Widget child;

  const TarjetaVidrio({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Vidrio(
      radio: BorderRadius.circular(30),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: child,
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
