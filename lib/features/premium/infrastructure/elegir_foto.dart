import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Foto del comprobante desde la galería, reducida para subir rápido.
Future<Uint8List?> elegirFotoDeGaleria() async {
  final archivo = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (archivo == null) return null;
  return archivo.readAsBytes();
}
