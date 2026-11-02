import 'package:academiapp_v2/admin/bandeja/bandeja_page.dart';
import 'package:academiapp_v2/admin/bandeja/repositorio_bandeja.dart';
import 'package:academiapp_v2/admin/tema_panel.dart';
import 'package:academiapp_v2/features/reportes/domain/reporte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final hoy = DateTime(2026, 11, 2, 10);

final reporteAna = Reporte(
  id: 'r1',
  usuarioId: 'ana',
  nombre: 'Ana Quispe',
  correo: 'ana@mail.pe',
  tipo: TipoReporte.preguntaExamen,
  mensaje: 'La clave no coincide con la solución.',
  contexto: const ContextoReporte(
    titulo: 'Exonerados 2025 · pregunta 3',
    examenId: 'exonerados-2025-03-16',
    preguntaId: 'exonerados-2025-03-16__p003',
  ),
  estado: EstadoReporte.nuevo,
  creadoEn: DateTime(2026, 11, 2, 8),
);

class Falso implements RepositorioBandeja {
  final hechos = <String>[];

  @override
  Stream<int> nuevos() => Stream.value(1);

  @override
  Future<List<Reporte>> reportes(EstadoReporte estado) async =>
      estado == EstadoReporte.nuevo && hechos.isEmpty ? [reporteAna] : [];

  @override
  Future<void> cambiarEstado(
    Reporte reporte,
    EstadoReporte estado, {
    String? respuesta,
  }) async => hechos.add('${reporte.id} ${estado.name} $respuesta');
}

void main() {
  testWidgets('bandeja: lleva a la pregunta y responde al resolver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final falso = Falso();
    final destinos = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaPanel(),
        home: Scaffold(
          body: BandejaPage(
            repositorio: falso,
            onAbrirEstudiante: (uid) => destinos.add('ficha $uid'),
            onIrPregunta: (e, p) => destinos.add('pregunta $e $p'),
            onIrTema: (v, t) => destinos.add('tema $v $t'),
            ahora: () => hoy,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nuevos · 1'), findsOneWidget);
    expect(find.text('La clave no coincide con la solución.'), findsWidgets);
    // Es de un examen: no ofrece ir a un tema.
    expect(find.text('Ir al tema'), findsNothing);

    await tester.tap(find.text('Ir a la pregunta'));
    expect(destinos, [
      'pregunta exonerados-2025-03-16 exonerados-2025-03-16__p003',
    ]);

    await tester.tap(find.text('Resolver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gracias, ya corregimos la pregunta.'));
    await tester.pump();
    // El "Resolver" del diálogo (el de la tarjeta queda detrás).
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Resolver'),
      ),
    );
    await tester.pumpAndSettle();

    expect(falso.hechos, ['r1 resuelto Gracias, ya corregimos la pregunta.']);
    expect(find.text('No hay reportes nuevos. Todo en orden.'), findsOneWidget);
  });
}
