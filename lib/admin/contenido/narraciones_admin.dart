import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../../features/narrations/domain/narracion.dart';

/// Un audio elegido del computador.
class ArchivoAudio {
  final String nombre;
  final Uint8List bytes;

  const ArchivoAudio(this.nombre, this.bytes);

  int get tamano => bytes.length;
}

/// Tope por audio (también en storage.rules). Un MP3 de 10 minutos a
/// 64 kbps pesa unos 5 MB.
const maxBytesAudio = 20 * 1024 * 1024;

const extensionesAudio = ['mp3', 'm4a', 'aac', 'ogg', 'wav'];

/// Narraciones de los temas desde el panel: el audio va a Storage (o, solo
/// para pruebas, un enlace pegado) y la ficha a Firestore.
abstract class RepositorioNarracionesAdmin implements RepositorioNarraciones {
  Future<void> agregar({
    required String versionId,
    required String temaId,
    required String tituloTema,
    required String titulo,
    required String tipo,
    String? descripcion,
    ArchivoAudio? audio,
    String? enlace,
  });

  Future<void> eliminar(Narracion narracion);
}

String tipoDeAudio(String nombre) {
  final n = nombre.toLowerCase();
  if (n.endsWith('.m4a')) return 'audio/mp4';
  if (n.endsWith('.aac')) return 'audio/aac';
  if (n.endsWith('.ogg')) return 'audio/ogg';
  if (n.endsWith('.wav')) return 'audio/wav';
  return 'audio/mpeg';
}

String extensionDe(String nombre) {
  final punto = nombre.lastIndexOf('.');
  final ext = punto == -1 ? '' : nombre.substring(punto + 1).toLowerCase();
  return extensionesAudio.contains(ext) ? ext : 'mp3';
}

/// "4.8 MB".
String tamanoLegible(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// El tipo que se guarda: el de la lista o, con "Otro", el que se escribió.
String tipoElegido(String elegido, String escrito) =>
    elegido == tipoOtro ? escrito.trim() : elegido;

/// Qué falta para poder agregar la narración (null si está completa).
String? errorNarracion({
  required String titulo,
  required String tipo,
  required ArchivoAudio? audio,
  required String enlace,
}) {
  if (titulo.trim().length < 3) return 'Escribe el título de la narración.';
  if (tipo.trim().isEmpty) return 'Escribe el tipo de narración.';
  if (audio == null && enlace.trim().isEmpty) {
    return 'Elige el audio (o pega un enlace para probar).';
  }
  if (audio != null && audio.tamano > maxBytesAudio) {
    return 'El audio pesa ${tamanoLegible(audio.tamano)}; el máximo es '
        '${tamanoLegible(maxBytesAudio)}.';
  }
  if (audio == null && !enlace.trim().startsWith('https://')) {
    return 'El enlace debe empezar con https://';
  }
  return null;
}

/// Abre el selector de archivos del sistema (un audio).
Future<ArchivoAudio?> elegirAudioDelComputador() async {
  final archivo = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Audio',
        extensions: extensionesAudio,
        mimeTypes: ['audio/*'],
      ),
    ],
  );
  if (archivo == null) return null;
  return ArchivoAudio(archivo.name, await archivo.readAsBytes());
}
