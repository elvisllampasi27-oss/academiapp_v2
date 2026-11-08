import 'package:flutter/material.dart';

import '../../../core/presentation/colores_app.dart';
import '../../../core/presentation/formato_fecha.dart';
import '../domain/entities/actividad_alumno.dart';

/// "Tu actividad", al estilo de los cuadritos de GitHub: cada columna es un
/// día de la matrícula (de su inicio a su fin) y cada fila una franja de
/// 3 horas del día. Cuanto más celeste, más preguntas respondió. Los días
/// que faltan se ven vacíos, así se nota hasta cuándo va la matrícula.
class MapaActividad extends StatelessWidget {
  final ActividadAlumno actividad;

  const MapaActividad({super.key, required this.actividad});

  static const _lado = 11.0;
  static const _separacion = 3.0;
  static const _paso = _lado + _separacion;
  static const _altoMeses = 16.0;
  static const _altoDias = 14.0;

  @override
  Widget build(BuildContext context) {
    final a = actividad;
    final alto = _altoMeses + ActividadAlumno.franjas * _paso + _altoDias;
    final fuerte = a.franjaFuerte;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: ColoresApp.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu actividad',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            a.diasRestantes > 0
                ? 'Tu matrícula va hasta el ${fechaCorta(a.fin).toLowerCase()}'
                      ' · te quedan ${a.diasRestantes} días'
                : 'Tu matrícula terminó el ${fechaCorta(a.fin).toLowerCase()}',
            style: const TextStyle(fontSize: 13, color: ColoresApp.apagado),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: alto,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horas del día (fijas al deslizar).
                Padding(
                  padding: const EdgeInsets.only(top: _altoMeses),
                  child: Column(
                    children: [
                      for (var f = 0; f < ActividadAlumno.franjas; f++)
                        SizedBox(
                          height: _paso,
                          width: 30,
                          child: Text(
                            f.isEven
                                ? '${f * ActividadAlumno.horasPorFranja} h'
                                : '',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: ColoresApp.tenue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _Dias(actividad: a, alto: alto),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    '${a.diasActivos} días activos',
                    if (a.racha > 0)
                      'racha de ${a.racha} ${a.racha == 1 ? 'día' : 'días'}',
                    if (fuerte != null)
                      'estudias más de ${fuerte * ActividadAlumno.horasPorFranja}'
                          ' a ${(fuerte + 1) * ActividadAlumno.horasPorFranja} h',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ColoresApp.apagado,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const _Leyenda(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Los días, deslizables de lado. Se abre mostrando hoy (cerca del borde
/// derecho, con algunos días por venir a la vista).
class _Dias extends StatefulWidget {
  final ActividadAlumno actividad;
  final double alto;

  const _Dias({required this.actividad, required this.alto});

  @override
  State<_Dias> createState() => _DiasState();
}

class _DiasState extends State<_Dias> {
  final _desplazamiento = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_desplazamiento.hasClients) return;
      final a = widget.actividad;
      final posicion = _desplazamiento.position;
      final hoy = a.indiceHoy.clamp(0, a.dias - 1) * MapaActividad._paso;
      final destino =
          hoy - posicion.viewportDimension + MapaActividad._paso * 6;
      _desplazamiento.jumpTo(
        destino.clamp(0.0, posicion.maxScrollExtent).toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _desplazamiento,
      scrollDirection: Axis.horizontal,
      child: CustomPaint(
        size: Size(widget.actividad.dias * MapaActividad._paso, widget.alto),
        painter: _Cuadritos(widget.actividad),
      ),
    );
  }
}

class _Cuadritos extends CustomPainter {
  final ActividadAlumno a;

  _Cuadritos(this.a);

  static const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static Color colorDe(int nivel) => switch (nivel) {
    1 => ColoresApp.celeste.withValues(alpha: 0.28),
    2 => ColoresApp.celeste.withValues(alpha: 0.5),
    3 => ColoresApp.celeste.withValues(alpha: 0.75),
    4 => ColoresApp.celeste,
    _ => const Color(0x12FFFFFF),
  };

  @override
  void paint(Canvas canvas, Size size) {
    const paso = MapaActividad._paso;
    const lado = MapaActividad._lado;
    const arriba = MapaActividad._altoMeses;
    const radio = Radius.circular(3);
    final futuro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x17FFFFFF);
    final relleno = Paint();

    for (var d = 0; d < a.dias; d++) {
      final x = d * paso;
      final dia = a.diaEn(d);

      // Mes arriba (al empezar la matrícula y cada día 1).
      if (d == 0 || dia.day == 1) {
        _texto(canvas, _meses[dia.month - 1], Offset(x, 0), ColoresApp.tenue);
      }
      // Inicial del día de la semana abajo.
      _texto(
        canvas,
        _iniciales[dia.weekday - 1],
        Offset(x + 2, arriba + ActividadAlumno.franjas * paso + 2),
        dia.weekday == DateTime.sunday ? ColoresApp.apagado : ColoresApp.tenue,
      );

      final esFuturo = d > a.indiceHoy;
      for (var f = 0; f < ActividadAlumno.franjas; f++) {
        final celda = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, arriba + f * paso, lado, lado),
          radio,
        );
        if (esFuturo) {
          canvas.drawRRect(celda.deflate(0.5), futuro);
        } else {
          relleno.color = colorDe(ActividadAlumno.nivel(a.en(d, f)));
          canvas.drawRRect(celda, relleno);
        }
      }
    }

    // Hoy: un marco ámbar alrededor de su columna.
    if (a.indiceHoy >= 0 && a.indiceHoy < a.dias) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            a.indiceHoy * paso - 2,
            arriba - 2,
            lado + 4,
            ActividadAlumno.franjas * paso + 1,
          ),
          const Radius.circular(5),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ColoresApp.ambar,
      );
    }
  }

  void _texto(Canvas canvas, String texto, Offset donde, Color color) {
    final pintor = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(fontSize: 9.5, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pintor.paint(canvas, donde);
    pintor.dispose();
  }

  @override
  bool shouldRepaint(_Cuadritos anterior) => anterior.a != a;
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 11, color: ColoresApp.tenue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Menos', style: estilo),
        const SizedBox(width: 4),
        for (var n = 0; n <= 4; n++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: _Cuadritos.colorDe(n),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        const SizedBox(width: 4),
        const Text('Más', style: estilo),
      ],
    );
  }
}
