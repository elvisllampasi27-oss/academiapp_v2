import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../features/narrations/domain/narracion.dart';
import '../../features/narrations/infrastructure/repositorio_narraciones_firestore.dart';
import '../registro_admin.dart';
import 'narraciones_admin.dart';

/// Audio en Storage (narraciones/{versión}/{tema}/{id}.mp3) y ficha en
/// Firestore (narraciones/{id}). Hoy (plan gratis) Storage se prueba con
/// el emulador; con Blaze, directo a Firebase.
class RepositorioNarracionesAdminFirestore
    extends RepositorioNarracionesFirestore
    implements RepositorioNarracionesAdmin {
  final FirebaseAuth auth;
  FirebaseStorage? _storage;

  RepositorioNarracionesAdminFirestore({
    super.firestore,
    FirebaseAuth? auth,
    this._storage,
  }) : auth = auth ?? FirebaseAuth.instance;

  FirebaseStorage get storage => _storage ??= (FirebaseStorage.instance
    // Sin esto, si Storage no responde la subida se reintenta 10 minutos.
    ..setMaxUploadRetryTime(const Duration(seconds: 30))
    ..setMaxOperationRetryTime(const Duration(seconds: 30)));

  @override
  Future<void> agregar({
    required String versionId,
    required String temaId,
    required String tituloTema,
    required String titulo,
    required String tipo,
    String? descripcion,
    ArchivoAudio? audio,
    String? enlace,
  }) async {
    final ref = firestore.collection('narraciones').doc();

    var url = enlace?.trim() ?? '';
    String? ruta;
    if (audio != null) {
      ruta =
          'narraciones/$versionId/$temaId/${ref.id}.${extensionDe(audio.nombre)}';
      final destino = storage.ref(ruta);
      final tarea = destino.putData(
        audio.bytes,
        SettableMetadata(contentType: tipoDeAudio(audio.nombre)),
      );
      try {
        await tarea.timeout(const Duration(minutes: 3));
      } on TimeoutException {
        await tarea.cancel();
        throw StateError('Storage no respondió en 3 minutos.');
      }
      url = await destino.getDownloadURL();
    }

    final lote = firestore.batch()
      ..set(ref, {
        'versionId': versionId,
        'temaId': temaId,
        'titulo': titulo.trim(),
        'tipo': tipo.trim(),
        if (descripcion != null && descripcion.trim().isNotEmpty)
          'descripcion': descripcion.trim(),
        'url': url,
        'rutaAudio': ?ruta,
        'creada': FieldValue.serverTimestamp(),
      })
      ..set(
        firestore.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'contenido',
          descripcion: 'Agregó la narración "$titulo" a "$tituloTema"',
        ),
      );
    await lote.commit();
  }

  @override
  Future<void> eliminar(Narracion narracion) async {
    final lote = firestore.batch()
      ..delete(firestore.collection('narraciones').doc(narracion.id))
      ..set(
        firestore.collection('registro_admin').doc(),
        entradaRegistro(
          auth,
          tipo: 'contenido',
          descripcion: 'Eliminó la narración "${narracion.titulo}"',
        ),
      );
    await lote.commit();

    if (narracion.rutaAudio case final ruta?) {
      try {
        await storage.ref(ruta).delete();
      } catch (_) {
        // La ficha ya no está: si el archivo no se pudo borrar, solo ocupa
        // espacio (no se ve en la app).
      }
    }
  }
}
