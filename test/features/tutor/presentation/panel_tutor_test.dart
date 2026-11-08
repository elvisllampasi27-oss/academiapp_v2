import 'dart:async';

import 'package:academiapp_v2/core/presentation/puma_tutor.dart';
import 'package:academiapp_v2/core/presentation/voz_puma.dart';
import 'package:academiapp_v2/features/tutor/domain/entities/mensaje_tutor.dart';
import 'package:academiapp_v2/features/tutor/domain/entities/respuesta_tutor.dart';
import 'package:academiapp_v2/features/tutor/domain/repositories/servicio_tutor.dart';
import 'package:academiapp_v2/features/tutor/presentation/conversacion_tutor.dart';
import 'package:academiapp_v2/features/tutor/presentation/widgets/panel_tutor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde solo cuando la prueba completa [respuesta].
class TutorEnEspera implements ServicioTutor {
  final respuesta = Completer<RespuestaTutor>();

  @override
  Future<RespuestaTutor> preguntar({
    required String versionId,
    required String temaId,
    required String pregunta,
    required List<MensajeTutor> historial,
  }) => respuesta.future;
}

/// Voz de mentira: guarda lo que se le pide leer.
class VozFalsa implements VozPuma {
  final void Function(bool) alCambiar;
  final VoidCallback alPalabra;
  final leidos = <String>[];
  bool cerrada = false;

  VozFalsa({required this.alCambiar, required this.alPalabra});

  @override
  Future<bool> preparar() async => true;

  @override
  Future<void> hablar(String texto) async {
    leidos.add(texto);
    alCambiar(true);
  }

  @override
  Future<void> callar() async => alCambiar(false);

  @override
  void cerrar() => cerrada = true;
}

void main() {
  late VozFalsa voz;
  final crearOriginal = VozPuma.crear;

  setUp(() {
    VozPuma.crear = ({required alCambiar, required alPalabra}) =>
        voz = VozFalsa(alCambiar: alCambiar, alPalabra: alPalabra);
  });
  tearDown(() => VozPuma.crear = crearOriginal);

  GestoPuma gestoDelEncabezado(WidgetTester tester) =>
      tester.widget<PumaTutor>(find.byType(PumaTutor).first).gesto;

  testWidgets('el puma piensa mientras espera y luego lee la respuesta', (
    tester,
  ) async {
    final tutor = TutorEnEspera();
    final conversacion = ConversacionTutor(
      servicio: tutor,
      versionId: 'v1',
      temaId: 'algebra-02',
    );
    addTearDown(conversacion.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelTutor(
            conversacion: conversacion,
            tituloTema: 'Polinomios',
            onCerrar: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(gestoDelEncabezado(tester), GestoPuma.atento);

    await tester.enterText(find.byType(TextField), '¿Qué es P(1)?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pump();
    expect(gestoDelEncabezado(tester), GestoPuma.pensando);

    tutor.respuesta.complete(
      const RespuestaTutor(
        texto: r'Es $\frac{12}{4}$',
        restantesHoy: 2,
        limiteDiario: 3,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(gestoDelEncabezado(tester), GestoPuma.atento);

    await tester.tap(find.text('Escuchar'));
    await tester.pump();
    expect(voz.leidos, [r'Es $\frac{12}{4}$']);
    expect(find.text('Callar'), findsOneWidget);
    expect(
      tester.widget<PumaTutor>(find.byType(PumaTutor).first).hablando,
      isTrue,
    );

    await tester.tap(find.text('Callar'));
    await tester.pump();
    expect(find.text('Escuchar'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(voz.cerrada, isTrue); // al cerrar el chat deja de hablar
  });

  group('lectura de fórmulas', () {
    test('fracciones, potencias y raíces se dicen como se leen', () {
      expect(textoParaVoz(r'$\frac{12}{4} = 3$'), '12 entre 4 igual a 3');
      expect(textoParaVoz(r'$x^2 + \sqrt{9}$'), 'x al cuadrado + raíz de 9');
      expect(textoParaVoz(r'$a \cdot b^{n}$'), 'a por b elevado a n');
    });

    test('quita las marcas de formato', () {
      expect(
        textoParaVoz('**Ojo:** revisa el #paso_2'),
        'Ojo: revisa el paso 2',
      );
    });
  });
}
