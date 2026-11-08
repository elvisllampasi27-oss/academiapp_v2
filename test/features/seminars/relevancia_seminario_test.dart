import 'package:academiapp_v2/features/seminars/domain/relevancia_seminario.dart';
import 'package:academiapp_v2/features/seminars/domain/seminario.dart';
import 'package:academiapp_v2/features/seminars/presentation/seminarios_inicio.dart';
import 'package:flutter_test/flutter_test.dart';

Seminario _s(String id, DateTime fecha, {String? curso}) =>
    Seminario(id: id, titulo: id, fecha: fecha, videoId: 'v', curso: curso);

void main() {
  const porReforzar = {
    'algebra': TemaPorReforzar(tema: 'Polinomios', dominio: 0.32),
  };

  test('relaciona el seminario con el curso aunque cambien tildes', () {
    final ayuda = ayudaDelSeminario(
      _s('a', DateTime(2026), curso: 'Álgebra '),
      porReforzar,
    );
    expect(ayuda?.tema, 'Polinomios');
    expect(
      ayudaDelSeminario(_s('b', DateTime(2026), curso: 'Física'), porReforzar),
      isNull,
    );
    expect(ayudaDelSeminario(_s('c', DateTime(2026)), porReforzar), isNull);
  });

  test(
    'en el inicio: primero el en vivo, luego el que ayuda, luego el próximo',
    () {
      final ahora = DateTime(2026, 11, 8, 18);
      final elegidos = SeminariosInicio.elegir(
        [
          _s('próximo', DateTime(2026, 11, 9, 19), curso: 'Física'),
          _s('ayuda', DateTime(2026, 11, 12, 19), curso: 'Álgebra'),
          _s('vivo', DateTime(2026, 11, 8, 17, 30), curso: 'Química'),
          _s('grabado sin relación', DateTime(2026, 11, 1), curso: 'Física'),
        ],
        porReforzar,
        ahora,
        maximo: 3,
      );
      expect(elegidos.map((s) => s.id), ['vivo', 'ayuda', 'próximo']);
    },
  );

  test('un grabado solo aparece en el inicio si le ayuda', () {
    final elegidos = SeminariosInicio.elegir(
      [
        _s('grabado útil', DateTime(2026, 11, 1), curso: 'Álgebra'),
        _s('grabado otro', DateTime(2026, 11, 1), curso: 'Física'),
      ],
      porReforzar,
      DateTime(2026, 11, 8),
    );
    expect(elegidos.map((s) => s.id), ['grabado útil']);
  });
}
