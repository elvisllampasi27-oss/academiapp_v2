import 'package:academiapp_v2/features/academic/domain/entities/recurso.dart';
import 'package:academiapp_v2/features/academic/presentation/utils/enlace_recurso.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes_material.dart';

void main() {
  test('un ID de YouTube de V1 se convierte en enlace completo', () {
    final enlace = enlaceDeRecurso(recurso('r', ubicacion: 'AbCdEfGhIjK'));

    expect(enlace.toString(), 'https://www.youtube.com/watch?v=AbCdEfGhIjK');
  });

  test('acepta https y rechaza otros esquemas', () {
    expect(
      enlaceDeRecurso(
        recurso('r', tipo: TipoRecurso.pdf, ubicacion: 'https://a.pe/x.pdf'),
      ),
      isNotNull,
    );
    expect(
      enlaceDeRecurso(
        recurso('r', tipo: TipoRecurso.pdf, ubicacion: 'http://a.pe/x.pdf'),
      ),
      isNull,
    );
    expect(
      enlaceDeRecurso(recurso('r', ubicacion: 'javascript:alert(1)')),
      isNull,
    );
    expect(enlaceDeRecurso(recurso('r', ubicacion: '   ')), isNull);
  });

  test('extrae el ID de YouTube de los formatos habituales', () {
    String? id(String ubicacion, {TipoRecurso tipo = TipoRecurso.video}) =>
        idYoutube(recurso('r', tipo: tipo, ubicacion: ubicacion));

    expect(id('pRRaLT4H-9s'), 'pRRaLT4H-9s');
    expect(
      id('https://www.youtube.com/watch?v=pRRaLT4H-9s&t=30'),
      'pRRaLT4H-9s',
    );
    expect(id('https://youtu.be/pRRaLT4H-9s'), 'pRRaLT4H-9s');
    expect(id('https://m.youtube.com/shorts/pRRaLT4H-9s'), 'pRRaLT4H-9s');
    expect(id('https://www.youtube.com/embed/pRRaLT4H-9s'), 'pRRaLT4H-9s');
  });

  test('no es video de YouTube: otro sitio, otro tipo o ID invalido', () {
    expect(idYoutube(recurso('r', ubicacion: 'https://vimeo.com/123')), isNull);
    expect(
      idYoutube(recurso('r', ubicacion: 'https://youtu.be/corto')),
      isNull,
    );
    expect(
      idYoutube(recurso('r', tipo: TipoRecurso.pdf, ubicacion: 'pRRaLT4H-9s')),
      isNull,
    );
  });
}
