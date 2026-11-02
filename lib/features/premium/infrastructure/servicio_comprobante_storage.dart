import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../domain/servicio_comprobante.dart';

/// Guarda la foto en Firebase Storage: `comprobantes/{uid}/{pagoId}.jpg`.
/// Requiere el plan Blaze y las reglas de storage.rules desplegadas.
class ServicioComprobanteStorage implements ServicioComprobante {
  FirebaseStorage? _storage;

  ServicioComprobanteStorage({FirebaseStorage? storage}) : _storage = storage;

  /// Se crea recién al subir: sin el plan Blaze la app igual abre.
  FirebaseStorage get storage => _storage ??= FirebaseStorage.instance;

  @override
  Future<String> subir({
    required String uid,
    required String pagoId,
    required Uint8List bytes,
  }) async {
    final ref = storage.ref('comprobantes/$uid/$pagoId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
