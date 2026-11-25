import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../domain/servicio_comprobante.dart';

/// Guarda la foto en Firebase Storage:
/// `comprobantes/{uid}/{pagoId}__{milisegundos}.jpg`. Un nombre nuevo en
/// cada intento: las reglas no dejan reemplazar un comprobante, así que si
/// la foto subió pero el pago no se guardó (se cortó el internet), el
/// reintento no choca con la foto anterior.
/// Requiere el plan Blaze y las reglas de storage.rules desplegadas.
class ServicioComprobanteStorage implements ServicioComprobante {
  FirebaseStorage? _storage;

  ServicioComprobanteStorage({this._storage});

  /// Se crea recién al subir: sin el plan Blaze la app igual abre.
  FirebaseStorage get storage => _storage ??= FirebaseStorage.instance;

  @override
  Future<String> subir({
    required String uid,
    required String pagoId,
    required Uint8List bytes,
  }) async {
    final marca = DateTime.now().millisecondsSinceEpoch;
    final ref = storage.ref('comprobantes/$uid/${pagoId}__$marca.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
