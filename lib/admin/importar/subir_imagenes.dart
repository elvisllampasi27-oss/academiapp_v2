import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Una imagen elegida del computador.
class ArchivoImagen {
  final String nombre;
  final Uint8List bytes;

  const ArchivoImagen(this.nombre, this.bytes);
}

/// Sube las figuras de exámenes y prácticas. Hoy (plan gratis) funciona con
/// el emulador de Storage para probar; con Blaze, directo a Firebase.
abstract class ServicioImagenesAdmin {
  /// Devuelve el enlace público de la imagen subida en [ruta].
  Future<String> subir({required String ruta, required Uint8List bytes});
}

class ServicioImagenesStorage implements ServicioImagenesAdmin {
  FirebaseStorage? _storage;

  ServicioImagenesStorage({this._storage});

  FirebaseStorage get storage => _storage ??= FirebaseStorage.instance;

  @override
  Future<String> subir({required String ruta, required Uint8List bytes}) async {
    final ref = storage.ref(ruta);
    await ref.putData(bytes, SettableMetadata(contentType: tipoDeImagen(ruta)));
    return ref.getDownloadURL();
  }
}

String tipoDeImagen(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.svg')) return 'image/svg+xml';
  return 'image/jpeg';
}

/// Abre el selector de archivos del sistema (varias imágenes a la vez).
Future<List<ArchivoImagen>> elegirImagenesDelComputador() async {
  final archivos = await openFiles(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Imágenes',
        extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'svg'],
        mimeTypes: ['image/*'],
      ),
    ],
  );
  return [
    for (final a in archivos) ArchivoImagen(a.name, await a.readAsBytes()),
  ];
}
