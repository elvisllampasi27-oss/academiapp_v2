import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/configuracion_academia.dart';
import '../domain/cupon.dart';
import '../domain/pago.dart';
import '../domain/repositorio_premium.dart';
import '../../../core/presentation/animaciones.dart';
import '../../../core/presentation/carga_puma.dart';

Future<bool> _abrirExterno(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

/// "987654321" -> enlace de WhatsApp con el mensaje (Perú: +51).
Uri? enlaceWhatsapp(String numero, String mensaje) {
  var digitos = numero.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return null;
  if (digitos.length == 9) digitos = '51$digitos';
  return Uri.parse(
    'https://wa.me/$digitos?text=${Uri.encodeComponent(mensaje)}',
  );
}

/// "Hazte Premium": beneficios, pago por Yape/Plin y estado de sus pagos.
class PremiumPage extends StatefulWidget {
  final String uid;
  final String nombre;
  final String correo;
  final RepositorioPremium repositorio;

  /// Elige la foto del comprobante. null si este dispositivo no puede.
  final Future<Uint8List?> Function()? elegirFoto;
  final Future<bool> Function(Uri enlace) abrirEnlace;
  final DateTime Function() ahora;

  const PremiumPage({
    super.key,
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.repositorio,
    this.elegirFoto,
    this.abrirEnlace = _abrirExterno,
    this.ahora = DateTime.now,
  });

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  late Future<EstadoPremium> _estado = widget.repositorio.cargar(widget.uid);

  final _operacion = TextEditingController();
  final _codigo = TextEditingController();
  MetodoPago _metodo = MetodoPago.yape;
  Cupon? _cupon;
  String? _avisoCupon;
  Uint8List? _foto;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _operacion.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _recargar() => setState(() {
    _estado = widget.repositorio.cargar(widget.uid);
  });

  Future<void> _aplicarCupon() async {
    final codigo = normalizarCodigo(_codigo.text);
    if (codigo.isEmpty) return;
    final cupon = await widget.repositorio.cupon(codigo, widget.ahora());
    if (!mounted) return;
    setState(() {
      _cupon = cupon;
      _avisoCupon = cupon == null
          ? 'Ese código no existe o ya no está vigente.'
          : null;
    });
  }

  Future<void> _adjuntar() async {
    final foto = await widget.elegirFoto?.call();
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _escribirWhatsapp(
    ConfiguracionAcademia c,
    String detalle,
  ) async {
    final enlace = enlaceWhatsapp(
      c.whatsapp,
      'Hola, soy ${widget.nombre} (${widget.correo}). $detalle',
    );
    if (enlace != null) await widget.abrirEnlace(enlace);
  }

  Future<void> _enviar(ConfiguracionAcademia c, {required bool beca}) async {
    final cupon = _cupon;
    if (!beca && !operacionValida(_operacion.text)) {
      setState(() => _error = 'Escribe el N.º de operación (6 a 20 dígitos).');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await widget.repositorio.enviarPago(
        uid: widget.uid,
        nombre: widget.nombre,
        correo: widget.correo,
        metodo: beca ? MetodoPago.beca : _metodo,
        operacion: beca ? '' : normalizarOperacion(_operacion.text),
        monto: cupon?.precioCon(c.precio) ?? c.precio,
        cupon: cupon?.codigo,
        foto: beca ? null : _foto,
      );
      if (!mounted) return;
      _operacion.clear();
      setState(() {
        _foto = null;
        _enviando = false;
      });
      _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e is StateError
            ? e.message
            : 'No se pudo enviar. Revisa tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: FutureBuilder<EstadoPremium>(
        future: _estado,
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: OutlinedButton(
                onPressed: _recargar,
                child: const Text('Reintentar'),
              ),
            );
          }
          final estado = s.data;
          if (estado == null) {
            return const Center(child: CargaPuma.compacta());
          }
          final c = estado.configuracion;
          final ahora = widget.ahora();
          final premium = esPremium(estado.premiumHasta, ahora);
          final pendiente = estado.pendiente;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: enCascada([
              _Encabezado(
                premium: premium,
                hasta: estado.premiumHasta,
                precio: c.precio,
                dias: c.diasPremium,
              ),
              const SizedBox(height: 16),
              _Beneficios(configuracion: c),
              const SizedBox(height: 16),
              if (pendiente != null)
                _Pendiente(
                  pago: pendiente,
                  onWhatsapp: c.whatsapp.isEmpty
                      ? null
                      : () => _escribirWhatsapp(
                          c,
                          'Envío el comprobante de mi pago de Premium '
                          '(N.º ${pendiente.operacion}).',
                        ),
                )
              else
                _formulario(c, premium),
              if (estado.pagos.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Mis pagos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final p in estado.pagos) _FilaPago(pago: p),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _formulario(ConfiguracionAcademia c, bool premium) {
    final cupon = _cupon;
    final precio = cupon?.precioCon(c.precio) ?? c.precio;
    final beca = cupon?.tipo == TipoCupon.premiumGratis;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              premium ? 'Extender Premium' : 'Hazte Premium',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigo,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Cupón o beca (opcional)',
                    ),
                    onSubmitted: (_) => _aplicarCupon(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _aplicarCupon,
                  child: const Text('Aplicar'),
                ),
              ],
            ),
            if (_avisoCupon case final aviso?)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  aviso,
                  style: const TextStyle(color: ColoresApp.naranja),
                ),
              ),
            if (cupon != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${cupon.codigo} · ${cupon.beneficio}',
                  style: const TextStyle(color: ColoresApp.celeste),
                ),
              ),
            const SizedBox(height: 18),
            if (beca)
              const Text(
                'Tu beca cubre Premium completo. Envíala y el equipo la '
                'activará.',
              )
            else if (c.yapeNumero.isEmpty)
              const Text(
                'La academia todavía no configuró el pago. Vuelve pronto.',
                style: TextStyle(color: ColoresApp.apagado),
              )
            else ...[
              _Paso(
                numero: 1,
                titulo: 'Paga S/ $precio por Yape o Plin',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.yapeNumero,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          if (c.yapeTitular.isNotEmpty)
                            Text(
                              'A nombre de ${c.yapeTitular}',
                              style: const TextStyle(color: ColoresApp.apagado),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar número',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.yapeNumero));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Número copiado.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              _Paso(
                numero: 2,
                titulo: 'Escribe el N.º de operación',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final m in const [
                          MetodoPago.yape,
                          MetodoPago.plin,
                        ])
                          ChoiceChip(
                            label: Text(m.etiqueta),
                            selected: _metodo == m,
                            onSelected: (_) => setState(() => _metodo = m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _operacion,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: 'N.º de operación',
                        helperText: 'Aparece en la constancia de Yape o Plin.',
                      ),
                    ),
                  ],
                ),
              ),
              _Paso(
                numero: 3,
                titulo: c.fotoComprobante && widget.elegirFoto != null
                    ? 'Adjunta la foto del comprobante'
                    : 'Después, envía la captura por WhatsApp',
                child: c.fotoComprobante && widget.elegirFoto != null
                    ? OutlinedButton.icon(
                        onPressed: _adjuntar,
                        icon: Icon(
                          _foto == null ? Icons.image_outlined : Icons.check,
                        ),
                        label: Text(
                          _foto == null ? 'Elegir foto' : 'Foto adjunta',
                        ),
                      )
                    : const Text(
                        'Al enviar, te aparecerá el botón de WhatsApp para '
                        'mandar la captura. Así se aprueba más rápido.',
                        style: TextStyle(color: ColoresApp.apagado),
                      ),
              ),
            ],
            if (_error case final e?)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  e,
                  style: const TextStyle(color: ColoresApp.naranja),
                ),
              ),
            const SizedBox(height: 14),
            if (beca || c.yapeNumero.isNotEmpty)
              FilledButton(
                onPressed: _enviando ? null : () => _enviar(c, beca: beca),
                child: _enviando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(beca ? 'Canjear beca' : 'Enviar pago'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final bool premium;
  final DateTime? hasta;
  final int precio;
  final int dias;

  const _Encabezado({
    required this.premium,
    required this.hasta,
    required this.precio,
    required this.dias,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColoresApp.ambar.withValues(alpha: premium ? 0.30 : 0.16),
            ColoresApp.panel,
          ],
        ),
        border: Border.all(color: ColoresApp.ambar.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium,
            color: ColoresApp.ambar,
            size: 40,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium ? 'Eres Premium' : 'Plan gratis',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premium && hasta != null
                      ? 'Hasta el ${fechaCorta(hasta!)} ${hasta!.year}'
                      : 'Premium: S/ $precio por $dias días',
                  style: const TextStyle(color: ColoresApp.apagado),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Beneficios extends StatelessWidget {
  final ConfiguracionAcademia configuracion;
  const _Beneficios({required this.configuracion});

  @override
  Widget build(BuildContext context) {
    final c = configuracion;
    final lista = [
      (
        Icons.forum_outlined,
        '${c.tutorPremium} dudas al tutor por día',
        'Con el plan gratis: ${c.tutorGratis}',
      ),
      if (c.simulacroSoloPremium)
        (
          Icons.timer_outlined,
          'Examen semanal y ranking',
          'Sábados y domingos, con tu nota por área y tu puesto',
        ),
      (
        Icons.trending_up,
        'Todo lo demás sigue igual',
        'Clases, prácticas y exámenes pasados',
      ),
    ];
    return Card(
      child: Column(
        children: [
          for (final (icono, titulo, detalle) in lista)
            ListTile(
              leading: Icon(icono, color: ColoresApp.ambar),
              title: Text(titulo),
              subtitle: Text(detalle),
            ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;
  final Widget child;

  const _Paso({
    required this.numero,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: ColoresApp.ambar,
            child: Text(
              '$numero',
              style: const TextStyle(
                color: ColoresApp.fondo,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pendiente extends StatelessWidget {
  final Pago pago;
  final VoidCallback? onWhatsapp;

  const _Pendiente({required this.pago, required this.onWhatsapp});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: ColoresApp.ambar),
                SizedBox(width: 10),
                Text(
                  'Tu pago está en revisión',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pago.metodo == MetodoPago.beca
                  ? 'Beca ${pago.cupon}. El equipo la activará pronto.'
                  : 'S/ ${pago.monto} · ${pago.metodo.etiqueta} · '
                        'N.º ${pago.operacion}. Se activa apenas lo confirmemos.',
              style: const TextStyle(color: ColoresApp.apagado),
            ),
            if (onWhatsapp != null && pago.fotoUrl == null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onWhatsapp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Enviar captura por WhatsApp'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaPago extends StatelessWidget {
  final Pago pago;
  const _FilaPago({required this.pago});

  @override
  Widget build(BuildContext context) {
    final (texto, color) = switch (pago.estado) {
      EstadoPago.pendiente => ('En revisión', ColoresApp.ambar),
      EstadoPago.aprobado => ('Aprobado', ColoresApp.celeste),
      EstadoPago.rechazado => ('Rechazado', ColoresApp.naranja),
    };
    return Card(
      child: ListTile(
        title: Text(
          pago.metodo == MetodoPago.beca
              ? 'Beca ${pago.cupon}'
              : 'S/ ${pago.monto} · ${pago.metodo.etiqueta}',
        ),
        subtitle: Text(
          [
            fechaCorta(pago.creadoEn),
            if (pago.estado == EstadoPago.rechazado && pago.motivo != null)
              pago.motivo!,
            if (pago.estado == EstadoPago.aprobado && pago.premiumHasta != null)
              'Premium hasta ${fechaCorta(pago.premiumHasta!)}',
          ].join(' · '),
        ),
        trailing: Text(
          texto,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
