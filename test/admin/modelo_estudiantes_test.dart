import 'package:academiapp_v2/admin/estudiantes/matricular_dialogo.dart';
import 'package:academiapp_v2/admin/estudiantes/modelo_estudiantes.dart';
import 'package:academiapp_v2/admin/graficos.dart';
import 'package:academiapp_v2/admin/widgets_panel.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curriculo.dart';
import 'package:academiapp_v2/features/academic/domain/entities/curso.dart';
import 'package:academiapp_v2/features/academic/domain/entities/tema.dart';
import 'package:academiapp_v2/features/academic/domain/entities/version_academica.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import 'package:academiapp_v2/features/adaptive_engine/domain/entities/recomendacion.dart';
import 'package:academiapp_v2/features/enrollment/domain/entities/matricula.dart';
import 'package:academiapp_v2/features/student_model/domain/entities/estado_dominio.dart';
import 'package:flutter_test/flutter_test.dart';

// Domingo 1 nov 2026, 10:00.
final hoy = DateTime(2026, 11, 1, 10);

Matricula matricula({
  required DateTime inicio,
  EstadoMatricula estado = EstadoMatricula.activa,
  DateTime? fecha,
  String version = 'v1',
}) => Matricula(
  id: 'm-${inicio.day}-${estado.name}',
  usuarioId: 'u',
  versionId: version,
  fechaMatricula: fecha ?? inicio,
  fechaInicioAcademico: inicio,
  estado: estado,
);

EstudianteAdmin estudiante(String nombre, {Matricula? m, DateTime? ultima}) =>
    EstudianteAdmin(
      uid: nombre.toLowerCase(),
      nombre: nombre,
      correo: '${nombre.toLowerCase()}@mail.pe',
      ultimaActividad: ultima,
      matricula: m,
    );

void main() {
  group('día académico', () {
    test('cuenta de lunes a sábado; el domingo no suma', () {
      // Inicio lunes 26 oct: lun..sáb = 6 días; hoy domingo sigue en 6.
      expect(diaAcademico(DateTime(2026, 10, 26), hoy), 6);
      expect(diaAcademico(DateTime(2026, 10, 26), DateTime(2026, 11, 2)), 7);
    });

    test('es 0 si todavía no empieza', () {
      expect(diaAcademico(DateTime(2026, 11, 2), hoy), 0);
    });
  });

  group('situación', () {
    test('sin matrícula, activo, programado y suspendido', () {
      expect(
        situacion(estudiante('Ana'), hoy),
        SituacionEstudiante.sinMatricula,
      );
      expect(
        situacion(
          estudiante('Ana', m: matricula(inicio: DateTime(2026, 10, 26))),
          hoy,
        ),
        SituacionEstudiante.activo,
      );
      expect(
        situacion(
          estudiante('Ana', m: matricula(inicio: DateTime(2026, 11, 2))),
          hoy,
        ),
        SituacionEstudiante.programado,
      );
      expect(
        situacion(
          estudiante(
            'Ana',
            m: matricula(
              inicio: DateTime(2026, 10, 26),
              estado: EstadoMatricula.suspendida,
            ),
          ),
          hoy,
        ),
        SituacionEstudiante.suspendido,
      );
    });

    test('sin actividad: activo que no entra hace 5 días o más', () {
      final m = matricula(inicio: DateTime(2026, 10, 1));
      expect(
        sinActividad(
          estudiante('A', m: m, ultima: DateTime(2026, 10, 27)),
          hoy,
        ),
        isTrue,
      );
      expect(
        sinActividad(
          estudiante('A', m: m, ultima: DateTime(2026, 10, 28)),
          hoy,
        ),
        isFalse,
      );
      // Nunca entró: se cuenta desde su día 1.
      expect(sinActividad(estudiante('A', m: m), hoy), isTrue);
      // Programado o sin matrícula: no aplica.
      expect(sinActividad(estudiante('A'), hoy), isFalse);
    });
  });

  test('matrícula vigente: la activa antes que la suspendida o la vieja', () {
    final vieja = matricula(
      inicio: DateTime(2026, 3, 2),
      estado: EstadoMatricula.finalizada,
    );
    final suspendida = matricula(
      inicio: DateTime(2026, 9, 1),
      estado: EstadoMatricula.suspendida,
    );
    final activa = matricula(inicio: DateTime(2026, 10, 1));

    expect(matriculaVigente([vieja, suspendida, activa]), activa);
    expect(matriculaVigente([vieja, suspendida]), suspendida);
    expect(matriculaVigente(const []), isNull);
  });

  test('filtrar: busca sin tildes y por filtro, ordenado por nombre', () {
    final lista = [
      estudiante('Óscar', m: matricula(inicio: DateTime(2026, 10, 26))),
      estudiante('Ana', m: matricula(inicio: DateTime(2026, 11, 2))),
      estudiante('Beto'),
    ];

    expect(filtrarEstudiantes(lista, hoy: hoy).map((e) => e.nombre), [
      'Ana',
      'Beto',
      'Óscar',
    ]);
    expect(
      filtrarEstudiantes(lista, hoy: hoy, texto: 'oscar').single.nombre,
      'Óscar',
    );
    expect(
      filtrarEstudiantes(
        lista,
        hoy: hoy,
        filtro: FiltroEstudiantes.programados,
      ).single.nombre,
      'Ana',
    );
    expect(
      filtrarEstudiantes(
        lista,
        hoy: hoy,
        filtro: FiltroEstudiantes.sinMatricula,
      ).single.nombre,
      'Beto',
    );
  });

  test('resumen: cifras y matrículas por semana', () {
    final lista = [
      estudiante(
        'A',
        m: matricula(
          inicio: DateTime(2026, 10, 27),
          fecha: DateTime(2026, 10, 26),
        ),
        ultima: DateTime(2026, 11, 1, 8),
      ),
      estudiante(
        'B',
        m: matricula(
          inicio: DateTime(2026, 11, 2),
          fecha: DateTime(2026, 10, 31),
        ),
      ),
      estudiante(
        'C',
        m: matricula(
          inicio: DateTime(2026, 10, 13),
          fecha: DateTime(2026, 10, 12),
        ),
        ultima: DateTime(2026, 10, 20),
      ),
      estudiante('D'),
    ];

    final r = calcularResumen(lista, hoy, semanas: 3);

    expect(r.activos, 2);
    expect(r.programados, 1);
    expect(r.sinMatricula, 1);
    expect(r.activosHoy, 1);
    expect(r.sinActividad.single.nombre, 'C');
    // Semanas que empiezan el lunes 12, 19 y 26 de octubre.
    expect(r.porSemana.map((s) => s.$1.day), [12, 19, 26]);
    expect(r.porSemana.map((s) => s.$2), [1, 0, 2]);
    expect(r.nuevasEstaSemana, 2);
  });

  test('versiones que aceptan matrículas', () {
    VersionAcademica v(EstadoVersionAcademica e, {DateTime? corte}) =>
        VersionAcademica(
          id: 'v',
          codigo: 'v',
          nombre: 'Ciclo',
          fechaApertura: DateTime(2026, 10, 1),
          estado: e,
          fechaCorte: corte,
        );

    expect(aceptaMatriculas(v(EstadoVersionAcademica.activa), hoy), isTrue);
    expect(
      aceptaMatriculas(v(EstadoVersionAcademica.activa, corte: hoy), hoy),
      isTrue,
    );
    expect(
      aceptaMatriculas(
        v(EstadoVersionAcademica.activa, corte: DateTime(2026, 10, 31)),
        hoy,
      ),
      isFalse,
    );
    expect(
      aceptaMatriculas(v(EstadoVersionAcademica.preparacion), hoy),
      isFalse,
    );
    expect(
      puedeMatricularse(estudiante('A', m: matricula(inicio: hoy)), hoy),
      isFalse,
    );
    expect(puedeMatricularse(estudiante('A'), hoy), isTrue);
  });

  group('temario', () {
    const curriculo = Curriculo(
      versionId: 'v1',
      areas: [],
      cursos: [
        Curso(id: 'alg', areaId: 'a', nombre: 'Álgebra', orden: 1),
        Curso(id: 'fis', areaId: 'a', nombre: 'Física', orden: 2),
      ],
      temas: [
        Tema(id: 'alg-1', cursoId: 'alg', titulo: 'Polinomios', orden: 1),
        Tema(id: 'alg-2', cursoId: 'alg', titulo: 'Productos', orden: 2),
        Tema(id: 'fis-1', cursoId: 'fis', titulo: 'Cinemática', orden: 1),
        Tema(id: 'fis-2', cursoId: 'fis', titulo: 'Dinámica', orden: 2),
      ],
    );

    test('fin del temario: 3 temas por día (2 el sábado)', () {
      final fin = finTemario(curriculo, DateTime(2026, 11, 6))!; // viernes
      expect(fin.temas, 4);
      expect(fin.dias, 2);
      expect(fin.fecha, DateTime(2026, 11, 7)); // sábado
    });

    test('avance del ciclo: día de hoy sobre el total de días', () {
      final e = estudiante('A', m: matricula(inicio: DateTime(2026, 10, 30)));
      final a = avanceCiclo(e, curriculo, hoy)!; // vie 30 y sáb 31: 2 de 2
      expect((a.dia, a.total), (2, 2));
      expect(a.fraccion, 1);
      expect(avanceCiclo(e, null, hoy)!.total, isNull);
      expect(avanceCiclo(estudiante('B'), curriculo, hoy), isNull);
    });

    test('dominio promedio por curso y temas para reforzar', () {
      ItemMiRuta item(String tema, double valor) => ItemMiRuta(
        temaId: tema,
        cantidadEvidencias: 3,
        estado: EstadoDominio(
          matriculaId: 'm',
          habilidadId: 'h-$tema',
          valor: valor,
          nivel: NivelDominio.medio,
          modeloVersion: 'bkt-v1',
          actualizadoEn: hoy,
        ),
        recomendacion: Recomendacion(
          id: 'r',
          matriculaId: 'm',
          habilidadId: 'h-$tema',
          tipo: TipoRecomendacion.practicar,
          motivo: '',
          prioridad: 1,
          fecha: hoy,
        ),
      );

      final (dominio, reforzar) = dominioDe([
        item('alg-1', 0.9),
        item('alg-2', 0.5),
        item('fis-1', 0.2),
      ], curriculo);

      expect(dominio.map((d) => d.curso), ['Álgebra', 'Física']);
      expect(dominio.first.valor, closeTo(0.7, 1e-9));
      expect(reforzar.single.tema, 'Cinemática');
    });
  });

  test('cuándo fue: hoy con hora, ayer, hace días', () {
    expect(haceCuanto(DateTime(2026, 11, 1, 8, 5), hoy), 'Hoy, 8:05');
    expect(haceCuanto(DateTime(2026, 10, 31, 22), hoy), 'Ayer');
    expect(haceCuanto(DateTime(2026, 10, 26), hoy), 'Hace 6 días');
    expect(haceCuanto(null, hoy), '—');
    expect(fechaPanel(DateTime(2026, 10, 23)), 'vie 23 oct 2026');
  });

  test('actividad por día: los últimos días con ceros donde no hubo', () {
    final dias = agruparActividad(
      practicas: [
        DateTime(2026, 11, 1, 8),
        DateTime(2026, 11, 1, 9),
        DateTime(2026, 10, 30),
        DateTime(2026, 10, 1), // fuera del periodo
      ],
      simulacros: [DateTime(2026, 10, 31, 19)],
      hoy: hoy,
      dias: 3,
    );

    expect(dias.map((d) => d.dia.day), [30, 31, 1]);
    expect(dias.map((d) => d.practicas), [1, 0, 2]);
    expect(dias.map((d) => d.simulacros), [0, 1, 0]);
  });

  test('techo del eje y saludo del panel', () {
    expect(techoEje(7), 8);
    expect(techoEje(23), 25);
    expect(techoEje(140), 150);
    expect(techoEje(0), 4);
    expect(
      nombreDesdeCorreo('elvis.llampasi.27@unsch.edu.pe'),
      'Elvis Llampasi',
    );
    expect(saludoPara(DateTime(2026, 11, 1, 22)), 'Buenas noches');
    expect(saludoPara(DateTime(2026, 11, 1, 9)), 'Buenos días');
  });
}
