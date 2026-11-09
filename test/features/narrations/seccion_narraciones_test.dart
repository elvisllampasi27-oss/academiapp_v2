import 'dart:async';

import 'package:academiapp_v2/features/narrations/domain/narracion.dart';
import 'package:academiapp_v2/features/narrations/presentation/reproductor_audio.dart';
import 'package:academiapp_v2/features/narrations/presentation/seccion_narraciones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repositorio implements RepositorioNarraciones {
  final List<Narracion> narraciones;
  final bool falla;

  _Repositorio(this.narraciones, {this.falla = false});

  @override
  Future<List<Narracion>> delTema({
    required String versionId,
    required String temaId,
  }) async {
    if (falla) throw StateError('sin red');
    return narraciones;
  }
}

class _Reproductor implements ReproductorAudio {
  final llamadas = <String>[];
  final _posicion = StreamController<Duration>.broadcast();
  final _duracion = StreamController<Duration>.broadcast();
  final _sonando = StreamController<bool>.broadcast();
  final _terminado = StreamController<void>.broadcast();

  @override
  Stream<Duration> get posicion => _posicion.stream;
  @override
  Stream<Duration> get duracion => _duracion.stream;
  @override
  Stream<bool> get sonando => _sonando.stream;
  @override
  Stream<void> get terminado => _terminado.stream;

  @override
  Future<void> reproducir(String url) async {
    llamadas.add('reproducir $url');
    _duracion.add(const Duration(minutes: 4, seconds: 5));
    _sonando.add(true);
  }

  @override
  Future<void> pausar() async {
    llamadas.add('pausar');
    _sonando.add(false);
  }

  @override
  Future<void> continuar() async {
    llamadas.add('continuar');
    _sonando.add(true);
  }

  @override
  Future<void> irA(Duration posicion) async => llamadas.add('irA $posicion');

  @override
  Future<void> velocidad(double factor) async =>
      llamadas.add('velocidad $factor');

  @override
  Future<void> liberar() async => llamadas.add('liberar');

  void avanzar(Duration d) => _posicion.add(d);
  void terminar() => _terminado.add(null);
}

Narracion _narracion(String id, String titulo, String tipo) => Narracion(
  id: id,
  versionId: 'v1',
  temaId: 'lit-03',
  titulo: titulo,
  tipo: tipo,
  url: 'https://x.pe/$id.mp3',
  descripcion: id == 'n1' ? 'Un cuento de César Vallejo.' : null,
);

void main() {
  final creados = <_Reproductor>[];

  setUp(() {
    creados.clear();
    ReproductorAudio.crear = () {
      final r = _Reproductor();
      creados.add(r);
      return r;
    };
  });

  tearDown(() => ReproductorAudio.crear = ReproductorAudioPlayers.new);

  Future<void> montar(
    WidgetTester tester,
    RepositorioNarraciones repositorio,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionNarraciones(
              key: ObjectKey(repositorio),
              repositorio: repositorio,
              versionId: 'v1',
              temaId: 'lit-03',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin narraciones (o sin red) no ocupa lugar', (tester) async {
    await montar(tester, _Repositorio(const []));
    expect(find.text('Narraciones'), findsNothing);

    await montar(tester, _Repositorio(const [], falla: true));
    expect(find.text('Narraciones'), findsNothing);
  });

  testWidgets('se escucha, se pausa, cambia de velocidad y vuelve a empezar', (
    tester,
  ) async {
    var pausasClase = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeccionNarraciones(
              repositorio: _Repositorio([
                _narracion('n1', 'Paco Yunque', 'Cuento'),
              ]),
              versionId: 'v1',
              temaId: 'lit-03',
              alReproducir: () => pausasClase++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Narraciones'), findsOneWidget);
    expect(find.text('Paco Yunque'), findsOneWidget);
    expect(find.text('Un cuento de César Vallejo.'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    // Nada se crea hasta que se toca "Escuchar".
    expect(creados, isEmpty);

    await tester.tap(find.byTooltip('Escuchar'));
    await tester.pumpAndSettle();
    final audio = creados.single;
    expect(audio.llamadas, ['reproducir https://x.pe/n1.mp3']);
    expect(pausasClase, 1, reason: 'la clase se pausa');
    expect(find.text('4:05'), findsOneWidget);

    audio.avanzar(const Duration(seconds: 75));
    // El aviso llega en un microtask, cuando no hay un frame pendiente:
    // un solo pump no alcanza a dibujarlo.
    await tester.pumpAndSettle();
    expect(find.text('1:15'), findsOneWidget);

    await tester.tap(find.text('1x'));
    await tester.pump();
    expect(find.text('1.25x'), findsOneWidget);
    expect(audio.llamadas.last, 'velocidad 1.25');

    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(audio.llamadas.last, 'pausar');

    await tester.tap(find.byTooltip('Escuchar'));
    await tester.pump();
    expect(audio.llamadas.last, 'continuar');

    // Al terminar, el botón vuelve a empezar (con la velocidad elegida).
    audio.terminar();
    // El aviso llega en un microtask, cuando no hay un frame pendiente:
    // un solo pump no alcanza a dibujarlo.
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    await tester.tap(find.byTooltip('Escuchar'));
    await tester.pumpAndSettle();
    expect(audio.llamadas.sublist(audio.llamadas.length - 2), [
      'reproducir https://x.pe/n1.mp3',
      'velocidad 1.25',
    ]);
    expect(creados, hasLength(1), reason: 'usa el mismo reproductor');

    await tester.pumpWidget(const SizedBox());
    expect(audio.llamadas.last, 'liberar');
  });

  testWidgets('al empezar otra, la anterior se pausa', (tester) async {
    await montar(
      tester,
      _Repositorio([
        _narracion('n1', 'Paco Yunque', 'Cuento'),
        _narracion('n2', 'Batalla de Ayacucho', 'Guerra o batalla'),
      ]),
    );

    await tester.tap(find.byTooltip('Escuchar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escuchar'));
    await tester.pumpAndSettle();

    expect(creados, hasLength(2));
    expect(creados.first.llamadas.last, 'pausar');
    expect(creados.last.llamadas, ['reproducir https://x.pe/n2.mp3']);
  });
}
