import 'package:academiapp_v2/admin/examenes/modelo_examen_admin.dart';
import 'package:academiapp_v2/admin/examenes/repositorio_examenes_admin.dart';
import 'package:academiapp_v2/admin/ranking/ranking_admin.dart';
import 'package:academiapp_v2/admin/ranking/ranking_page.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ResultadoSemanal resultado(
  String nombre,
  int puntaje,
  int segundos, {
  int minuto = 0,
}) => ResultadoSemanal(
  uid: nombre.toLowerCase(),
  nombre: nombre,
  puntaje: puntaje,
  correctas: puntaje ~/ 5,
  total: 20,
  segundos: segundos,
  terminado: DateTime(2026, 11, 7, 10, minuto),
);

class FalsoSemanales implements RepositorioExamenesAdmin {
  @override
  Future<List<ExamenAdmin>> examenes() async => const [
    ExamenAdmin(
      id: 'v1__s01',
      titulo: 'Semana 1 · Ciclo 2026-II',
      tipo: 'semanal',
      fecha: '',
      estado: 'publicado',
      totalPreguntas: 20,
      versionId: 'v1',
      semana: 1,
    ),
    ExamenAdmin(
      id: 'v1__s02',
      titulo: 'Semana 2 · Ciclo 2026-II',
      tipo: 'semanal',
      fecha: '',
      estado: 'borrador',
      totalPreguntas: 20,
      versionId: 'v1',
      semana: 2,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FalsoRanking implements RepositorioRankingAdmin {
  @override
  Future<List<ResultadoSemanal>> resultados(String examenId) async => [
    resultado('Beto Ríos', 70, 1500),
    resultado('Ana Quispe', 90, 1800),
    resultado('Caro Soto', 70, 1200),
  ];
}

void main() {
  test('ranking: más nota, luego menos tiempo, luego quién terminó antes', () {
    final orden = ordenarRanking([
      resultado('A', 80, 900, minuto: 5),
      resultado('B', 80, 900, minuto: 1),
      resultado('C', 95, 2000),
    ]);
    expect([for (final (p, r) in orden) '$p${r.nombre}'], ['1C', '2B', '3A']);
    expect(duracionBreve(754), '12:34');
    expect(idExamenSemanal('v1', 3), 'v1__s03');
  });

  testWidgets('panel: solo exámenes publicados y la tabla en orden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final abiertos = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: RankingPage(
            semanales: FalsoSemanales(),
            ranking: FalsoRanking(),
            onAbrirEstudiante: abiertos.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Semana 1 · Ciclo 2026-II'), findsOneWidget);
    expect(find.text('Semana 2 · Ciclo 2026-II'), findsNothing);
    expect(find.text('77 %'), findsOneWidget); // promedio
    // Ana también sale como "Mejor nota": la de la tabla es la última.
    final ana = tester.getTopLeft(find.text('Ana Quispe').last).dy;
    final caro = tester.getTopLeft(find.text('Caro Soto')).dy;
    final beto = tester.getTopLeft(find.text('Beto Ríos')).dy;
    expect(ana < caro && caro < beto, isTrue);

    await tester.tap(find.text('Caro Soto'));
    expect(abiertos, ['caro soto']);
  });
}
