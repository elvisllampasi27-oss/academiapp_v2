import 'dart:typed_data';

import 'package:academiapp_v2/admin/contenido/narraciones_admin.dart';
import 'package:academiapp_v2/features/narrations/domain/narracion.dart';
import 'package:academiapp_v2/features/narrations/infrastructure/repositorio_narraciones_firestore.dart';
import 'package:academiapp_v2/features/narrations/presentation/seccion_narraciones.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lectura de Firestore', () {
    test('arma la narración y completa lo que falta', () {
      final n = narracionDesdeMapa('n1', {
        'versionId': 'v1',
        'temaId': 'lit-03',
        'titulo': 'Paco Yunque',
        'tipo': '  ',
        'descripcion': '',
        'url': 'https://x.pe/a.mp3',
        'rutaAudio': 'narraciones/v1/lit-03/n1.mp3',
        'creada': Timestamp.fromDate(DateTime(2026, 11, 2)),
      })!;
      expect(n.titulo, 'Paco Yunque');
      expect(n.tipo, 'Narración');
      expect(n.descripcion, isNull);
      expect(n.rutaAudio, 'narraciones/v1/lit-03/n1.mp3');
      expect(n.creada, DateTime(2026, 11, 2));
    });

    test('sin enlace o sin tema no sirve', () {
      expect(
        narracionDesdeMapa('n1', {'versionId': 'v1', 'temaId': 't'}),
        isNull,
      );
      expect(narracionDesdeMapa('n1', {'url': 'https://x.pe/a.mp3'}), isNull);
    });

    test('en el orden en que se subieron; sin fecha, al final', () {
      Narracion n(String id, DateTime? creada) => Narracion(
        id: id,
        versionId: 'v',
        temaId: 't',
        titulo: id,
        tipo: 'Cuento',
        url: 'https://x.pe/$id.mp3',
        creada: creada,
      );
      final orden = ordenarNarraciones([
        n('c', null),
        n('b', DateTime(2026, 2)),
        n('a', DateTime(2026, 1)),
      ]);
      expect([for (final x in orden) x.id], ['a', 'b', 'c']);
    });
  });

  group('reproductor', () {
    test('tiempo legible y velocidades', () {
      expect(formatoTiempo(const Duration(seconds: 5)), '0:05');
      expect(formatoTiempo(const Duration(minutes: 10, seconds: 3)), '10:03');
      expect(
        formatoTiempo(const Duration(hours: 1, minutes: 2, seconds: 9)),
        '1:02:09',
      );
      expect(
        [for (final v in velocidadesNarracion) etiquetaVelocidad(v)],
        ['1x', '1.25x', '1.5x'],
      );
    });

    test('ícono según el tipo (y uno general para los escritos)', () {
      expect(iconoNarracion('Guerra o batalla'), Icons.shield_outlined);
      expect(iconoNarracion('Biografía'), Icons.person_outline);
      expect(iconoNarracion('Crónica'), Icons.headphones_outlined);
    });
  });

  group('formulario del panel', () {
    final audio = ArchivoAudio('cuento.MP3', Uint8List(10));

    test('con "Otro" se guarda el tipo escrito', () {
      expect(tipoElegido('Mito', 'x'), 'Mito');
      expect(tipoElegido(tipoOtro, '  Crónica '), 'Crónica');
      expect(tipoElegido(tipoOtro, ' '), '');
    });

    test('qué falta para agregarla', () {
      expect(
        errorNarracion(titulo: 'Ab', tipo: 'Cuento', audio: audio, enlace: ''),
        contains('título'),
      );
      expect(
        errorNarracion(titulo: 'Paco', tipo: '', audio: audio, enlace: ''),
        contains('tipo'),
      );
      expect(
        errorNarracion(titulo: 'Paco', tipo: 'Cuento', audio: null, enlace: ''),
        contains('audio'),
      );
      expect(
        errorNarracion(
          titulo: 'Paco',
          tipo: 'Cuento',
          audio: null,
          enlace: 'http://x.pe/a.mp3',
        ),
        contains('https://'),
      );
      expect(
        errorNarracion(
          titulo: 'Paco',
          tipo: 'Cuento',
          audio: ArchivoAudio('largo.mp3', Uint8List(maxBytesAudio + 1)),
          enlace: '',
        ),
        contains('máximo'),
      );
      expect(
        errorNarracion(
          titulo: 'Paco',
          tipo: 'Cuento',
          audio: audio,
          enlace: '',
        ),
        isNull,
      );
      expect(
        errorNarracion(
          titulo: 'Paco',
          tipo: 'Cuento',
          audio: null,
          enlace: 'https://x.pe/a.mp3',
        ),
        isNull,
      );
    });

    test('tipo y extensión del archivo', () {
      expect(tipoDeAudio(audio.nombre), 'audio/mpeg');
      expect(tipoDeAudio('a.m4a'), 'audio/mp4');
      expect(extensionDe(audio.nombre), 'mp3');
      expect(extensionDe('raro.xyz'), 'mp3');
      expect(tamanoLegible(5 * 1024 * 1024), '5.0 MB');
    });
  });
}
