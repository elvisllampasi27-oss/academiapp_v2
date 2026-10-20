import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/services/secuencia_academica_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SecuenciaAcademicaService();

  test('genera la secuencia academica por rondas', () {
    const cursos = [
      Curso(
        id: 'matematica',
        areaId: 'ciencias',
        nombre: 'Matemática',
        orden: 1,
      ),
      Curso(id: 'lenguaje', areaId: 'letras', nombre: 'Lenguaje', orden: 2),
      Curso(id: 'historia', areaId: 'sociales', nombre: 'Historia', orden: 3),
    ];

    const temas = [
      Tema(
        id: 'mat-1',
        cursoId: 'matematica',
        titulo: 'Matemática 1',
        orden: 1,
      ),
      Tema(
        id: 'mat-2',
        cursoId: 'matematica',
        titulo: 'Matemática 2',
        orden: 2,
      ),
      Tema(
        id: 'mat-3',
        cursoId: 'matematica',
        titulo: 'Matemática 3',
        orden: 3,
      ),
      Tema(id: 'len-1', cursoId: 'lenguaje', titulo: 'Lenguaje 1', orden: 1),
      Tema(id: 'len-2', cursoId: 'lenguaje', titulo: 'Lenguaje 2', orden: 2),
      Tema(id: 'his-1', cursoId: 'historia', titulo: 'Historia 1', orden: 1),
      Tema(id: 'his-2', cursoId: 'historia', titulo: 'Historia 2', orden: 2),
      Tema(id: 'his-3', cursoId: 'historia', titulo: 'Historia 3', orden: 3),
    ];

    final resultado = service.generar(cursos: cursos, temas: temas);

    expect(resultado.map((tema) => tema.id).toList(), [
      'mat-1',
      'len-1',
      'his-1',
      'mat-2',
      'len-2',
      'his-2',
      'mat-3',
      'his-3',
    ]);
  });
}
