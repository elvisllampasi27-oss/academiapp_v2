import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/solicitud_docente.dart';

class RepositorioDocentesFirestore implements RepositorioDocentes {
  final FirebaseFirestore firestore;

  RepositorioDocentesFirestore({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<SolicitudDocente?> miSolicitud(String uid) async {
    final d = await firestore.collection('solicitudes_docente').doc(uid).get();
    final datos = d.data();
    return datos == null ? null : solicitudDesdeMapa(d.id, datos);
  }

  @override
  Future<PerfilDocente?> perfil(String uid) async {
    final d = await firestore.collection('docentes').doc(uid).get();
    final datos = d.data();
    if (datos == null) return null;
    return PerfilDocente(
      uid: uid,
      nombre: datos['nombre'] as String? ?? 'Docente',
      cursos: datos['cursos'] as String? ?? '',
      enlaces: [
        for (final e in datos['enlaces'] as List? ?? const [])
          if (e is String) e,
      ],
    );
  }

  @override
  Future<void> solicitar({
    required String uid,
    required String nombre,
    required String correo,
    required String celular,
    required String cursos,
    required List<String> enlaces,
    required String mensaje,
  }) => firestore.collection('solicitudes_docente').doc(uid).set({
    'uid': uid,
    'nombre': nombre.trim(),
    'correo': correo.trim(),
    'celular': celularLimpio(celular),
    'cursos': cursos.trim(),
    'enlaces': enlaces,
    'mensaje': mensaje.trim(),
    'estado': EstadoSolicitudDocente.pendiente.name,
    'creadaEn': FieldValue.serverTimestamp(),
  });
}

SolicitudDocente? solicitudDesdeMapa(String uid, Map<String, dynamic> d) {
  final estado = EstadoSolicitudDocente.desde(d['estado']);
  if (estado == null) return null;
  final creada = d['creadaEn'];
  final motivo = (d['motivo'] as String?)?.trim() ?? '';

  return SolicitudDocente(
    uid: uid,
    nombre: d['nombre'] as String? ?? '',
    correo: d['correo'] as String? ?? '',
    celular: d['celular'] as String? ?? '',
    cursos: d['cursos'] as String? ?? '',
    enlaces: [
      for (final e in d['enlaces'] as List? ?? const [])
        if (e is String) e,
    ],
    mensaje: d['mensaje'] as String? ?? '',
    estado: estado,
    // Recién escrita, la hora del servidor todavía no llegó.
    creadaEn: creada is Timestamp ? creada.toDate() : DateTime.now(),
    motivo: motivo.isEmpty ? null : motivo,
  );
}
