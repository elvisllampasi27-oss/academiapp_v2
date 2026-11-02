import 'dart:typed_data';

import '../features/academic/domain/repositories/repositorio_contenido.dart';
import '../features/academic/domain/repositories/repositorio_curriculo.dart';
import '../features/academic/domain/repositories/repositorio_plan_academico.dart';
import '../features/academic/domain/repositories/repositorio_progreso_clase.dart';
import '../features/academic/domain/repositories/repositorio_recurso.dart';
import '../features/academic/domain/repositories/repositorio_version_academica.dart';
import '../features/academic/infrastructure/repositories/repositorio_contenido_firestore.dart';
import '../features/academic/infrastructure/repositories/repositorio_curriculo_firestore.dart';
import '../features/academic/infrastructure/repositories/repositorio_plan_academico_firestore.dart';
import '../features/academic/infrastructure/repositories/repositorio_progreso_clase_firestore.dart';
import '../features/academic/infrastructure/repositories/repositorio_recurso_firestore.dart';
import '../features/academic/infrastructure/repositories/repositorio_version_academica_firestore.dart';
import '../features/assessment/domain/repositories/repositorio_evaluacion.dart';
import '../features/assessment/domain/repositories/servicio_correccion_evaluacion.dart';
import '../features/assessment/infrastructure/repositories/repositorio_evaluacion_firestore.dart';
import '../features/assessment/infrastructure/services/servicio_correccion_cloud_functions.dart';
import '../features/avisos/domain/aviso.dart';
import '../features/avisos/infrastructure/repositorio_avisos_firestore.dart';
import '../features/enrollment/domain/repositories/repositorio_matricula.dart';
import '../features/enrollment/infrastructure/repositories/repositorio_matricula_firestore.dart';
import '../features/exams/domain/repositories/repositorio_examenes.dart';
import '../features/exams/domain/repositories/servicio_examenes.dart';
import '../features/exams/infrastructure/repositorio_examenes_firestore.dart';
import '../features/exams/infrastructure/servicio_examenes_cloud_functions.dart';
import '../features/identity/domain/repositories/registro_actividad.dart';
import '../features/identity/domain/repositories/repositorio_usuario.dart';
import '../features/identity/domain/repositories/servicio_autenticacion.dart';
import '../features/identity/domain/repositories/servicio_autenticacion_google.dart';
import '../features/identity/domain/repositories/servicio_recuperacion_contrasena.dart';
import '../features/identity/infrastructure/repositories/repositorio_usuario_firestore.dart';
import '../features/identity/infrastructure/services/firebase_servicio_autenticacion.dart';
import '../features/reportes/domain/reporte.dart';
import '../features/reportes/infrastructure/repositorio_reportes_firestore.dart';
import '../features/seminars/domain/seminario.dart';
import '../features/premium/domain/repositorio_premium.dart';
import '../features/premium/infrastructure/elegir_foto.dart';
import '../features/premium/infrastructure/repositorio_premium_firestore.dart';
import '../features/premium/infrastructure/servicio_comprobante_storage.dart';
import '../features/seminars/infrastructure/repositorio_seminarios_firestore.dart';
import '../features/student_model/domain/repositories/repositorio_evidencia.dart';
import '../features/student_model/infrastructure/repositories/repositorio_evidencia_firestore.dart';
import '../features/tutor/domain/repositories/servicio_tutor.dart';
import '../features/tutor/infrastructure/services/servicio_tutor_cloud_functions.dart';

/// Composition root de la app del estudiante: el ÚNICO lugar donde se
/// eligen las implementaciones (Firebase). Las pantallas y servicios
/// reciben interfaces, así se prueban con datos falsos.
class Dependencias {
  final ServicioAutenticacion autenticacion;
  final ServicioRecuperacionContrasena recuperacion;
  final ServicioAutenticacionGoogle google;
  final RepositorioUsuario usuarios;
  final RegistroActividad actividad;

  final RepositorioMatricula matriculas;
  final RepositorioVersionAcademica versiones;
  final RepositorioPlanAcademico planes;

  /// El temario se lee por versión (y se guarda en memoria).
  final RepositorioCurriculo Function(String versionId) curriculoDe;
  final RepositorioContenido contenidos;
  final RepositorioRecurso recursos;
  final RepositorioProgresoClase progresoClases;

  final RepositorioEvaluacion evaluaciones;
  final ServicioCorreccionEvaluacion correccion;
  final RepositorioEvidencia evidencias;
  final ServicioTutor tutor;
  final RepositorioExamenes examenes;
  final ServicioExamenes servicioExamenes;
  final RepositorioSeminarios seminarios;
  final RepositorioPremium premium;
  final RepositorioReportes reportes;
  final RepositorioAvisos avisos;

  /// Foto del comprobante (galería). null si no se puede en este equipo.
  final Future<Uint8List?> Function()? elegirFoto;

  const Dependencias({
    required this.autenticacion,
    required this.recuperacion,
    required this.google,
    required this.usuarios,
    required this.actividad,
    required this.matriculas,
    required this.versiones,
    required this.planes,
    required this.curriculoDe,
    required this.contenidos,
    required this.recursos,
    required this.progresoClases,
    required this.evaluaciones,
    required this.correccion,
    required this.evidencias,
    required this.tutor,
    required this.examenes,
    required this.servicioExamenes,
    required this.seminarios,
    required this.premium,
    required this.reportes,
    required this.avisos,
    this.elegirFoto,
  });

  factory Dependencias.firebase() {
    final autenticacion = FirebaseServicioAutenticacion();
    final usuarios = RepositorioUsuarioFirestore();

    return Dependencias(
      autenticacion: autenticacion,
      recuperacion: autenticacion,
      google: autenticacion,
      usuarios: usuarios,
      actividad: usuarios,
      matriculas: RepositorioMatriculaFirestore(),
      versiones: RepositorioVersionAcademicaFirestore(),
      planes: RepositorioPlanAcademicoFirestore(),
      curriculoDe: (versionId) =>
          RepositorioCurriculoFirestore(versionId: versionId),
      contenidos: RepositorioContenidoFirestore(),
      recursos: RepositorioRecursoFirestore(),
      progresoClases: RepositorioProgresoClaseFirestore(),
      evaluaciones: RepositorioEvaluacionFirestore(),
      correccion: ServicioCorreccionCloudFunctions(),
      evidencias: RepositorioEvidenciaFirestore(),
      tutor: ServicioTutorCloudFunctions(),
      examenes: RepositorioExamenesFirestore(),
      servicioExamenes: ServicioExamenesCloudFunctions(),
      seminarios: RepositorioSeminariosFirestore(),
      premium: RepositorioPremiumFirestore(
        comprobantes: ServicioComprobanteStorage(),
      ),
      reportes: RepositorioReportesFirestore(),
      avisos: RepositorioAvisosFirestore(),
      elegirFoto: elegirFotoDeGaleria,
    );
  }
}
