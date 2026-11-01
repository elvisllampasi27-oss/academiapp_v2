import 'package:academiapp_v2/core/presentation/video/reproductor_clase.dart';
import 'package:academiapp_v2/features/seminars/domain/seminario.dart';
import 'package:academiapp_v2/features/seminars/infrastructure/repositorio_seminarios_firestore.dart';
import 'package:academiapp_v2/features/seminars/presentation/seminarios_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RepositorioSeminariosEnMemoria implements RepositorioSeminarios {
  final List<Seminario> lista;

  RepositorioSeminariosEnMemoria(this.lista);

  @override
  Future<List<Seminario>> listar() async => lista;
}

Widget reproductorFalso({
  required String videoId,
  required double inicio,
  required ControlClase control,
  required AlAvanzarClase alAvanzar,
}) => Text('video $videoId');

void main() {
  final ahora = DateTime(2026, 11, 1, 12);

  final grabado = Seminario(
    id: 'g',
    titulo: 'Repaso de polinomios',
    curso: 'Álgebra',
    fecha: DateTime(2026, 10, 30, 19),
    videoId: 'AbCdEfGhIjK',
    duracionMinutos: 60,
  );
  final proximo = Seminario(
    id: 'p',
    titulo: 'Magnitudes proporcionales',
    curso: 'Aritmética',
    fecha: DateTime(2026, 11, 7, 19),
    videoId: 'ZyXwVuTsRqP',
  );

  test('el mismo seminario pasa de proximo a en vivo y a grabado', () {
    expect(proximo.estado(ahora), EstadoSeminario.proximo);
    expect(
      proximo.estado(DateTime(2026, 11, 7, 19, 30)),
      EstadoSeminario.enVivo,
    );
    expect(proximo.estado(DateTime(2026, 11, 7, 21)), EstadoSeminario.grabado);
  });

  test('lee el seminario de Firestore', () {
    final s = seminarioDesdeMapa('x', {
      'titulo': 'A',
      'cursoNombre': 'Álgebra',
      'fecha': Timestamp.fromDate(DateTime(2026, 11, 7, 19)),
      'videoId': 'AbCdEfGhIjK',
      'duracionMinutos': 45,
    })!;
    expect(s.curso, 'Álgebra');
    expect(s.fin, DateTime(2026, 11, 7, 19, 45));
    expect(seminarioDesdeMapa('y', {'titulo': 'sin fecha'}), isNull);
  });

  testWidgets('muestra el proximo en vivo y los grabados se ven en la app', (
    tester,
  ) async {
    final abiertos = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SeminariosPage(
          repositorio: RepositorioSeminariosEnMemoria([grabado, proximo]),
          ahora: () => ahora,
          abrirEnlace: (uri) async {
            abiertos.add(uri);
            return true;
          },
          reproductor: reproductorFalso,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Magnitudes proporcionales'), findsOneWidget);
    expect(find.text('Aritmética · Sábado 7 nov · 7:00 p. m.'), findsOneWidget);

    await tester.tap(find.text('Abrir en YouTube'));
    await tester.pump();
    expect(abiertos.single.queryParameters['v'], 'ZyXwVuTsRqP');

    await tester.tap(find.text('Repaso de polinomios'));
    await tester.pumpAndSettle();
    expect(find.text('video AbCdEfGhIjK'), findsOneWidget);
  });
}
