import 'package:academiapp_v2/app/inicio/inicio_page.dart';
import 'package:academiapp_v2/features/academic/domain/entities/actividad_programada.dart';
import 'package:academiapp_v2/features/academic/domain/entities/contexto_dia_estudiante.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/dia_academico.dart';
import 'package:academiapp_v2/features/academic/domain/entities/plan_academico.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _plan = PlanAcademico(
  id: 'plan-v1',
  versionId: 'version-1',
  nombre: 'Plan V1',
  activo: true,
);

const _cursos = [
  Curso(id: 'aritmetica', areaId: 'matematica', nombre: 'Aritmética', orden: 4),
  Curso(id: 'algebra', areaId: 'matematica', nombre: 'Álgebra', orden: 5),
];

const _temas = [
  Tema(
    id: 'aritmetica-02',
    cursoId: 'aritmetica',
    titulo: 'Magnitudes proporcionales',
    orden: 2,
  ),
  Tema(id: 'algebra-02', cursoId: 'algebra', titulo: 'Polinomios', orden: 2),
];

const _actividades = [
  ActividadProgramada(
    id: 'a1',
    diaId: 'dia-8',
    temaId: 'aritmetica-02',
    orden: 1,
  ),
  ActividadProgramada(id: 'a2', diaId: 'dia-8', temaId: 'algebra-02', orden: 2),
];

ContextoDiaEstudiante _contexto({bool conDia = true}) {
  return ContextoDiaEstudiante(
    plan: _plan,
    dia: conDia
        ? const DiaAcademico(numero: 8, actividades: _actividades)
        : null,
    actividades: conDia ? _actividades : const [],
    cursos: _cursos,
    temas: _temas,
  );
}

ItemMiRuta _refuerzo() {
  final fecha = DateTime(2026, 10, 31);
  return ItemMiRuta(
    recomendacion: Recomendacion(
      id: 'r',
      matriculaId: 'm1',
      habilidadId: 'aritmetica-02__general',
      tipo: TipoRecomendacion.reforzar,
      motivo: '',
      prioridad: 3,
      fecha: fecha,
    ),
    estado: EstadoDominio(
      matriculaId: 'm1',
      habilidadId: 'aritmetica-02__general',
      valor: 0.12,
      nivel: NivelDominio.bajo,
      modeloVersion: 'bkt-v1',
      actualizadoEn: fecha,
    ),
    cantidadEvidencias: 2,
    temaId: 'aritmetica-02',
  );
}

void main() {
  late List<String> abiertos;
  late int verRuta;

  Widget inicio(ContextoDiaEstudiante dia, List<ItemMiRuta> ruta) {
    return MaterialApp(
      home: Scaffold(
        body: InicioPage(
          nombre: 'Elvis Brayan Llampasi',
          hoy: DateTime(2026, 10, 31),
          dia: dia,
          ruta: ruta,
          onAbrirTema: (tema, _) => abiertos.add(tema.id),
          onVerRuta: () => verRuta++,
          onAbrirPerfil: () {},
        ),
      ),
    );
  }

  setUp(() {
    abiertos = [];
    verRuta = 0;
  });

  Future<void> mostrar(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
  }

  testWidgets('saluda y muestra la ruta de hoy con lo ya practicado', (
    tester,
  ) async {
    await mostrar(tester, inicio(_contexto(), [_refuerzo()]));

    expect(find.text('Hola, Elvis'), findsOneWidget);
    expect(find.text('Sábado 31 oct · Día académico 8'), findsOneWidget);
    expect(find.text('1 de 2 temas'), findsOneWidget);
    expect(find.text('Aritmética · practicado'), findsOneWidget);
    expect(find.text('Álgebra · pendiente'), findsOneWidget);
    expect(find.text('REFORZAR'), findsOneWidget);
    expect(find.text('Dominio 12 %'), findsOneWidget);

    await tester.tap(find.text('Polinomios'));
    expect(abiertos, ['algebra-02']);

    await tester.tap(find.text('Ver ruta'));
    expect(verRuta, 1);
  });

  testWidgets('sin evidencias invita a practicar', (tester) async {
    await mostrar(tester, inicio(_contexto(), const []));

    expect(find.text('0 de 2 temas'), findsOneWidget);
    expect(find.textContaining('Resuelve las prácticas'), findsOneWidget);
  });

  testWidgets('el domingo no hay temas', (tester) async {
    await mostrar(tester, inicio(_contexto(conDia: false), const []));

    expect(find.textContaining('Hoy no tienes temas'), findsOneWidget);
  });
}
