import 'dart:typed_data';

/// Sube la foto del comprobante y devuelve su URL. Solo se usa si
/// "foto del comprobante" está activo en el panel (requiere plan Blaze).
abstract class ServicioComprobante {
  Future<String> subir({
    required String uid,
    required String pagoId,
    required Uint8List bytes,
  });
}
