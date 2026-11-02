import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/academic/domain/entities/curriculo.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/academic/infrastructure/repositories/repositorio_curriculo_firestore.dart';
import '../../features/adaptive_engine/domain/entities/item_mi_ruta.dart';
import '../../features/adaptive_engine/domain/services/construir_mi_ruta_service.dart';
import '../../features/enrollment/domain/entities/matricula.dart';
import '../../features/student_model/infrastructure/repositories/repositorio_evidencia_firestore.dart';
import 'modelo_estudiantes.dart';
import 'repositorio_estudiantes_admin.dart';

/// Lee directo de Firestore: las reglas exigen el permiso `admin`.
/// Con cientos de estudiantes, abrir la lista cuesta ~2 lecturas por
/// estudiante (perfil y matrícula); suficiente para el plan gratis.
class RepositorioEstudiantesAdminFirestore
    implements RepositorioEstudiantesAdmin {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final _curriculos = <String, RepositorioCurriculoFirestore>{};

  RepositorioEstudiantesAdminFirestore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : db = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance;

  @override
  Future<List<EstudianteAdmin>> estudiantes() async {
    final (usuarios, matriculas) = await (
      db.collection('usuarios').where('rol', isEqualTo: 'estudiante').get(),
      db.collection('matriculas').get(),
    ).wait;

    final porUsuario = <String, List<Matricula>>{};
    for (final d in matriculas.docs) {
      final m = _matricula(d);
      if (m != null) porUsuario.putIfAbsent(m.usuarioId, () => []).add(m);
    }

    return [
      for (final d in usuarios.docs)
        _estudiante(d, matriculaVigente(porUsuario[d.id] ?? const [])),
    ];
  }

  @override
  Future<List<VersionAcademica>> versiones() async {
    final consulta = await db.collection('versiones_academicas').get();
    return [for (final d in consulta.docs) ?_version(d.id, d.data())]
      ..sort((a, b) => b.fechaApertura.compareTo(a.fechaApertura));
  }

  @override
  Future<Curriculo> curriculo(String versionId) => _curriculos
      .putIfAbsent(
        versionId,
        () =>
            RepositorioCurriculoFirestore(versionId: versionId, firestore: db),
      )
      .obtener();

  @override
  Future<List<AccionAdmin>> accionesRecientes({int limite = 8}) async {
    final consulta = await db
        .collection('registro_admin')
        .orderBy('fecha', descending: true)
        .limit(limite)
        .get();
    return [for (final d in consulta.docs) _accion(d.data())];
  }

  @override
  Future<List<ActividadDia>> actividadReciente({int dias = 14}) async {
    final hoy = DateTime.now();
    final desde = Timestamp.fromDate(
      DateTime(hoy.year, hoy.month, hoy.day - (dias - 1)),
    );
    // Solo se leen los documentos de esos días (un índice simple por campo).
    final (practicas, simulacros) = await (
      db
          .collection('intentos_evaluacion')
          .where('fechaFin', isGreaterThanOrEqualTo: desde)
          .get(),
      db
          .collection('simulacros')
          .where('terminadoEn', isGreaterThanOrEqualTo: desde)
          .get(),
    ).wait;
    List<DateTime> fechas(
      QuerySnapshot<Map<String, dynamic>> q,
      String campo,
    ) => [
      for (final d in q.docs)
        if (d.data()[campo] case final Timestamp t) t.toDate(),
    ];
    return agruparActividad(
      practicas: fechas(practicas, 'fechaFin'),
      simulacros: fechas(simulacros, 'terminadoEn'),
      hoy: hoy,
      dias: dias,
    );
  }

  @override
  Future<FichaEstudiante> ficha(String uid) async {
    final (perfil, matriculasSnap, simulacrosSnap, registroSnap) = await (
      db.collection('usuarios').doc(uid).get(),
      db.collection('matriculas').where('usuarioId', isEqualTo: uid).get(),
      db.collection('simulacros').where('usuarioId', isEqualTo: uid).get(),
      db.collection('registro_admin').where('usuarioId', isEqualTo: uid).get(),
    ).wait;

    if (!perfil.exists) throw StateError('El estudiante ya no existe.');

    final matriculas = [for (final d in matriculasSnap.docs) ?_matricula(d)]
      ..sort((a, b) => b.fechaMatricula.compareTo(a.fechaMatricula));
    final vigente = matriculaVigente(matriculas);
    final estudiante = _estudiante(perfil, vigente);

    final simulacros = [
      for (final d in simulacrosSnap.docs)
        if (d.data() case {
          'estado': 'completado',
          'terminadoEn': final Timestamp fin,
          'correctas': final num correctas,
        })
          SimulacroAdmin(
            fecha: fin.toDate(),
            correctas: correctas.toInt(),
            total: (d.data()['total'] as num?)?.toInt() ?? 20,
            segundos: (d.data()['tiempoUsadoSegundos'] as num?)?.toInt() ?? 0,
          ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));

    final acciones = [for (final d in registroSnap.docs) _accion(d.data())]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    if (vigente == null) {
      return FichaEstudiante(
        estudiante: estudiante,
        matriculas: matriculas,
        version: null,
        fin: null,
        clasesCompletas: 0,
        totalTemas: 0,
        respuestas: 0,
        correctas: 0,
        simulacros: simulacros,
        dominio: const [],
        reforzar: const [],
        acciones: acciones,
      );
    }

    final (versionSnap, progresoSnap, intentosSnap, ruta) = await (
      db.collection('versiones_academicas').doc(vigente.versionId).get(),
      db.collection('progreso_clases').where('usuarioId', isEqualTo: uid).get(),
      db
          .collection('intentos_evaluacion')
          .where('usuarioId', isEqualTo: uid)
          .get(),
      _ruta(uid, vigente.id),
    ).wait;

    Curriculo? temario;
    try {
      temario = await curriculo(vigente.versionId);
    } catch (_) {
      temario = null; // versión sin temario cargado: la ficha igual se ve
    }

    var respuestas = 0;
    var correctas = 0;
    for (final d in intentosSnap.docs) {
      final datos = d.data();
      if (datos['matriculaId'] != vigente.id) continue;
      respuestas += (datos['total'] as num?)?.toInt() ?? 0;
      correctas += (datos['correctas'] as num?)?.toInt() ?? 0;
    }

    final (dominio, reforzar) = temario == null
        ? (const <DominioCurso>[], const <TemaReforzar>[])
        : dominioDe(ruta, temario);

    return FichaEstudiante(
      estudiante: estudiante,
      matriculas: matriculas,
      version: versionSnap.exists
          ? _version(versionSnap.id, versionSnap.data()!)
          : null,
      fin: temario == null
          ? null
          : finTemario(temario, vigente.fechaInicioAcademico),
      clasesCompletas: progresoSnap.docs
          .where(
            (d) =>
                d.data()['versionId'] == vigente.versionId &&
                d.data()['completada'] == true,
          )
          .length,
      totalTemas: temario?.temas.where((t) => t.activo).length ?? 0,
      respuestas: respuestas,
      correctas: correctas,
      simulacros: simulacros,
      dominio: dominio,
      reforzar: reforzar,
      acciones: acciones,
    );
  }

  @override
  Future<void> matricular({
    required EstudianteAdmin estudiante,
    required VersionAcademica version,
    required DateTime fechaMatricula,
    required DateTime inicio,
  }) async {
    final lote = db.batch();
    lote.set(db.collection('matriculas').doc(), {
      'usuarioId': estudiante.uid,
      'versionId': version.id,
      'fechaMatricula': Timestamp.fromDate(fechaMatricula),
      'fechaInicioAcademico': Timestamp.fromDate(inicio),
      'estado': EstadoMatricula.activa.name,
      'creadaPor': _correo,
    });
    _registrar(
      lote,
      tipo: 'matricula',
      usuarioId: estudiante.uid,
      descripcion:
          'Matriculó a ${estudiante.nombre} en ${version.nombre} '
          '(inicia el ${fechaPanel(inicio)})',
    );
    await lote.commit();
  }

  @override
  Future<void> cambiarInicio({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required DateTime inicio,
  }) async {
    final lote = db.batch();
    lote.update(db.collection('matriculas').doc(matricula.id), {
      'fechaInicioAcademico': Timestamp.fromDate(inicio),
    });
    _registrar(
      lote,
      tipo: 'inicio',
      usuarioId: estudiante.uid,
      descripcion:
          'Cambió el inicio de ${estudiante.nombre}: '
          '${fechaPanel(matricula.fechaInicioAcademico)} → ${fechaPanel(inicio)}',
    );
    await lote.commit();
  }

  @override
  Future<void> cambiarEstado({
    required EstudianteAdmin estudiante,
    required Matricula matricula,
    required EstadoMatricula estado,
  }) async {
    final lote = db.batch();
    lote.update(db.collection('matriculas').doc(matricula.id), {
      'estado': estado.name,
    });
    final verbo = switch (estado) {
      EstadoMatricula.suspendida => 'Suspendió',
      EstadoMatricula.activa => 'Reactivó',
      EstadoMatricula.finalizada => 'Finalizó',
      EstadoMatricula.programada => 'Programó',
    };
    _registrar(
      lote,
      tipo: 'estado',
      usuarioId: estudiante.uid,
      descripcion: '$verbo la matrícula de ${estudiante.nombre}',
    );
    await lote.commit();
  }

  // ---------------------------------------------------------------

  /// Dominio por tema (BKT), igual que en Mi Ruta del estudiante.
  Future<List<ItemMiRuta>> _ruta(String uid, String matriculaId) async {
    try {
      return await ConstruirMiRutaService(
        repositorio: RepositorioEvidenciaFirestore(firestore: db),
      ).construir(usuarioId: uid, matriculaId: matriculaId);
    } catch (_) {
      return const [];
    }
  }

  String get _correo => auth.currentUser?.email ?? 'admin';

  void _registrar(
    WriteBatch lote, {
    required String tipo,
    required String descripcion,
    String? usuarioId,
  }) {
    lote.set(db.collection('registro_admin').doc(), {
      'tipo': tipo,
      'descripcion': descripcion,
      'usuarioId': ?usuarioId,
      'adminUid': auth.currentUser?.uid,
      'adminCorreo': _correo,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  EstudianteAdmin _estudiante(
    DocumentSnapshot<Map<String, dynamic>> d,
    Matricula? matricula,
  ) {
    final datos = d.data() ?? const {};
    return EstudianteAdmin(
      uid: d.id,
      nombre: (datos['nombre'] as String?) ?? '(sin nombre)',
      correo: (datos['correo'] as String?) ?? '',
      carrera: datos['carreraPostulada'] as String?,
      registro: (datos['fechaCreacion'] as Timestamp?)?.toDate(),
      ultimaActividad: (datos['ultimaActividad'] as Timestamp?)?.toDate(),
      matricula: matricula,
    );
  }

  Matricula? _matricula(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final datos = d.data();
    final estado = EstadoMatricula.values.asNameMap()[datos['estado']];
    final inicio = datos['fechaInicioAcademico'];
    final fecha = datos['fechaMatricula'];
    if (estado == null || inicio is! Timestamp || fecha is! Timestamp) {
      return null; // documento incompleto: no se muestra
    }
    return Matricula(
      id: d.id,
      usuarioId: datos['usuarioId'] as String,
      versionId: datos['versionId'] as String,
      fechaMatricula: fecha.toDate(),
      fechaInicioAcademico: inicio.toDate(),
      fechaFin: (datos['fechaFin'] as Timestamp?)?.toDate(),
      estado: estado,
    );
  }

  VersionAcademica? _version(String id, Map<String, dynamic> datos) {
    final apertura = datos['fechaApertura'];
    final estado = EstadoVersionAcademica.values.asNameMap()[datos['estado']];
    if (apertura is! Timestamp || estado == null) return null;
    return VersionAcademica(
      id: id,
      codigo: (datos['codigo'] as String?) ?? id,
      nombre: (datos['nombre'] as String?) ?? id,
      fechaApertura: apertura.toDate(),
      fechaCorte: (datos['fechaCorte'] as Timestamp?)?.toDate(),
      estado: estado,
    );
  }

  AccionAdmin _accion(Map<String, dynamic> datos) => AccionAdmin(
    tipo: (datos['tipo'] as String?) ?? '',
    descripcion: (datos['descripcion'] as String?) ?? '',
    usuarioId: datos['usuarioId'] as String?,
    adminCorreo: (datos['adminCorreo'] as String?) ?? '',
    // Recién escrita, la hora del servidor puede venir vacía un instante.
    fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}
