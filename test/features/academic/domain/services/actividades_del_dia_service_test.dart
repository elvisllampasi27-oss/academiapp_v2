import 'package:academiapp_v2/features/academic/domain/entities/actividad_programada.dart';
import 'package:academiapp_v2/features/academic/domain/entities/dia_academico.dart';
import 'package:academiapp_v2/features/academic/domain/services/actividades_del_dia_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ActividadesDelDiaService();

  final calendario = [
    DiaAcademico(
      numero: 1,
      fecha: DateTime(2026, 10, 19),
      actividades: const [
        ActividadProgramada(
          id: 'actividad-1',
          diaId: 'dia-1',
          temaId: 'matematica-1',
          orden: 1,
          estado: EstadoActividadProgramada.publicada,
        ),
        ActividadProgramada(
          id: 'actividad-2',
          diaId: 'dia-1',
          temaId: 'lenguaje-1',
          orden: 2,
          estado: EstadoActividadProgramada.publicada,
        ),
        ActividadProgramada(
          id: 'actividad-3',
          diaId: 'dia-1',
          temaId: 'historia-1',
          orden: 3,
          estado: EstadoActividadProgramada.publicada,
        ),
      ],
    ),
    DiaAcademico(
      numero: 2,
      fecha: DateTime(2026, 10, 20),
      actividades: const [
        ActividadProgramada(
          id: 'actividad-4',
          diaId: 'dia-2',
          temaId: 'fisica-1',
          orden: 1,
          estado: EstadoActividadProgramada.publicada,
        ),
      ],
    ),
  ];

  test('devuelve las actividades correspondientes a la fecha', () {
    final resultado = service.obtener(
      calendario: calendario,
      fecha: DateTime(2026, 10, 19, 14, 30),
    );

    expect(resultado.length, 3);
    expect(resultado[0].temaId, 'matematica-1');
    expect(resultado[1].temaId, 'lenguaje-1');
    expect(resultado[2].temaId, 'historia-1');
  });

  test('ignora la hora y compara solamente el dia', () {
    final resultado = service.obtener(
      calendario: calendario,
      fecha: DateTime(2026, 10, 20, 23, 45),
    );

    expect(resultado.length, 1);
    expect(resultado.first.temaId, 'fisica-1');
  });

  test('devuelve lista vacia cuando no hay actividades ese dia', () {
    final resultado = service.obtener(
      calendario: calendario,
      fecha: DateTime(2026, 10, 25),
    );

    expect(resultado, isEmpty);
  });

  test('solo devuelve actividades publicadas', () {
    final calendarioConEstados = [
      DiaAcademico(
        numero: 1,
        fecha: DateTime(2026, 10, 19),
        actividades: const [
          ActividadProgramada(
            id: 'actividad-publicada',
            diaId: 'dia-1',
            temaId: 'matematica-1',
            orden: 1,
            estado: EstadoActividadProgramada.publicada,
          ),
          ActividadProgramada(
            id: 'actividad-preparada',
            diaId: 'dia-1',
            temaId: 'lenguaje-1',
            orden: 2,
            estado: EstadoActividadProgramada.preparada,
          ),
          ActividadProgramada(
            id: 'actividad-archivada',
            diaId: 'dia-1',
            temaId: 'historia-1',
            orden: 3,
            estado: EstadoActividadProgramada.archivada,
          ),
        ],
      ),
    ];

    final resultado = service.obtener(
      calendario: calendarioConEstados,
      fecha: DateTime(2026, 10, 19),
    );

    expect(resultado.length, 1);
    expect(resultado.first.temaId, 'matematica-1');
  });
}
