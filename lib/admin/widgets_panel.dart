import 'package:flutter/material.dart';

import 'graficos.dart';
import 'tema_panel.dart';

/// Piezas visuales comunes del panel (mismo aspecto en todas las secciones).

class EncabezadoPanel extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;
  final Widget? migas;

  const EncabezadoPanel({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
    this.migas,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (migas case final m?) ...[m, const SizedBox(height: 8)],
            Text(
              titulo,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            if (subtitulo case final s?) ...[
              const SizedBox(height: 4),
              Text(s, style: TextStyle(color: p.apagado, fontSize: 14)),
            ],
          ],
        ),
        if (acciones.isNotEmpty)
          Wrap(spacing: 10, runSpacing: 10, children: acciones),
      ],
    );
  }
}

class TarjetaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const TarjetaPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    // Material (no un Container pintado): así los ListTile, Switch y
    // Checkbox de adentro muestran bien su fondo y su efecto al tocar.
    return Material(
      color: PaletaPanel.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: PaletaPanel.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class TituloTarjeta extends StatelessWidget {
  final String texto;
  final Widget? extra;

  const TituloTarjeta(this.texto, {super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ?extra,
        ],
      ),
    );
  }
}

/// Cifra grande con su explicación, una píldora opcional arriba a la
/// derecha y una mini gráfica de tendencia.
class IndicadorPanel extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? nota;
  final Color? color;
  final String? pildora;
  final Color? colorPildora;
  final List<double>? tendencia;

  /// Avance de 0 a 1 que se muestra como anillo a la derecha.
  final double? anillo;
  final VoidCallback? onTap;

  const IndicadorPanel({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.nota,
    this.color,
    this.pildora,
    this.colorPildora,
    this.tendencia,
    this.anillo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final tonoPildora = colorPildora ?? p.apagado;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: TarjetaPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      etiqueta,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ),
                  if (pildora case final texto?)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: tonoPildora.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        texto,
                        style: TextStyle(
                          color: tonoPildora,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      valor,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: color ?? p.texto,
                      ),
                    ),
                  ),
                  if (tendencia case final serie? when serie.length > 1)
                    SizedBox(
                      width: 84,
                      height: 30,
                      child: CustomPaint(
                        painter: PintorTendencia(serie, color ?? p.acento),
                      ),
                    ),
                  if (anillo case final a?)
                    AnilloAvance(a, tamano: 46, color: color ?? p.acento),
                ],
              ),
              if (nota case final n?)
                Text(n, style: TextStyle(color: p.tenue, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

enum TonoInsignia { gris, acento, secundario, alerta }

class Insignia extends StatelessWidget {
  final String texto;
  final TonoInsignia tono;

  const Insignia(this.texto, {super.key, this.tono = TonoInsignia.gris});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final color = switch (tono) {
      TonoInsignia.gris => p.apagado,
      TonoInsignia.acento => p.acento,
      TonoInsignia.secundario => p.secundario,
      TonoInsignia.alerta => p.alerta,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class BarraAvance extends StatelessWidget {
  final double valor;
  final Color? color;
  final double alto;

  const BarraAvance(this.valor, {super.key, this.color, this.alto = 6});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: LinearProgressIndicator(
        value: valor.clamp(0, 1).toDouble(),
        minHeight: alto,
        color: color ?? PaletaPanel.de(context).texto,
        backgroundColor: PaletaPanel.borde,
      ),
    );
  }
}

class AvatarIniciales extends StatelessWidget {
  final String nombre;
  const AvatarIniciales(this.nombre, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final inicial = nombre.trim().isEmpty
        ? '?'
        : nombre.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 17,
      backgroundColor: p.acento.withValues(alpha: 0.18),
      child: Text(
        inicial,
        style: TextStyle(color: p.acento, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const FilaDato(this.etiqueta, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PaletaPanel.linea)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(etiqueta, style: TextStyle(color: p.apagado)),
          ),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reparte [children] en columnas iguales según el ancho disponible.
class RejillaPanel extends StatelessWidget {
  final List<Widget> children;
  final double anchoMinimo;
  final double espacio;

  const RejillaPanel({
    super.key,
    required this.children,
    this.anchoMinimo = 200,
    this.espacio = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = ((c.maxWidth + espacio) / (anchoMinimo + espacio))
            .floor()
            .clamp(1, children.length)
            .toInt();
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final hijo in children) SizedBox(width: ancho, child: hijo),
          ],
        );
      },
    );
  }
}

/// Dos columnas (principal y lateral) en pantallas anchas; una en angostas.
class DosColumnas extends StatelessWidget {
  final Widget principal;
  final Widget lateral;
  final int flexPrincipal;
  final int flexLateral;

  const DosColumnas({
    super.key,
    required this.principal,
    required this.lateral,
    this.flexPrincipal = 2,
    this.flexLateral = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 960) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [principal, const SizedBox(height: 16), lateral],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flexPrincipal, child: principal),
            const SizedBox(width: 16),
            Expanded(flex: flexLateral, child: lateral),
          ],
        );
      },
    );
  }
}

/// Columna con separación fija entre sus hijos.
class ColumnaPanel extends StatelessWidget {
  final List<Widget> children;
  final double espacio;

  const ColumnaPanel({super.key, required this.children, this.espacio = 16});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: espacio),
          children[i],
        ],
      ],
    );
  }
}

/// Espera un Future y muestra carga, error con "Reintentar" o el contenido.
class FuturoPanel<T> extends StatelessWidget {
  final Future<T> futuro;
  final Widget Function(BuildContext context, T datos) builder;
  final VoidCallback onReintentar;

  const FuturoPanel({
    super.key,
    required this.futuro,
    required this.builder,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: futuro,
      builder: (context, s) {
        if (s.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar.'),
                const SizedBox(height: 4),
                Text(
                  '${s.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PaletaPanel.de(context).tenue),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onReintentar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        if (!s.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return builder(context, s.data as T);
      },
    );
  }
}

/// Contenido desplazable de una sección, con los márgenes del panel.
class PaginaPanel extends StatelessWidget {
  final List<Widget> children;

  const PaginaPanel({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ColumnaPanel(espacio: 20, children: children),
        ),
      ),
    );
  }
}

void avisarPanel(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// "elvis.llampasi.27@unsch.edu.pe" -> "Elvis Llampasi".
String nombreDesdeCorreo(String correo) {
  final partes = correo
      .split('@')
      .first
      .split(RegExp(r'[._\-]+'))
      .where((p) => p.isNotEmpty && int.tryParse(p) == null)
      .take(2)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}');
  final nombre = partes.join(' ');
  return nombre.isEmpty ? correo : nombre;
}

/// "Buenos días" hasta las 12, "Buenas tardes" hasta las 19.
String saludoPara(DateTime ahora) => ahora.hour < 12
    ? 'Buenos días'
    : ahora.hour < 19
    ? 'Buenas tardes'
    : 'Buenas noches';

/// Título grande con el degradado dorado del panel.
class TituloDorado extends StatelessWidget {
  final String texto;
  final double tamano;

  const TituloDorado(this.texto, {super.key, this.tamano = 30});

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(colors: p.dorado).createShader(r),
      child: Text(
        texto,
        style: TextStyle(fontSize: tamano, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Píldora con un punto de color: "● Datos al día".
class PildoraEstado extends StatelessWidget {
  final String texto;
  final Color color;

  const PildoraEstado(this.texto, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Pide un texto corto (motivo, nota). Devuelve null si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  required String confirmar,
  List<String> sugerencias = const [],
  String inicial = '',
}) {
  final controlador = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, actualizar) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controlador,
                autofocus: true,
                onChanged: (_) => actualizar(() {}),
                decoration: InputDecoration(labelText: etiqueta),
              ),
              if (sugerencias.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in sugerencias)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => actualizar(() => controlador.text = s),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: controlador.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, controlador.text.trim()),
            child: Text(confirmar),
          ),
        ],
      ),
    ),
  );
}
