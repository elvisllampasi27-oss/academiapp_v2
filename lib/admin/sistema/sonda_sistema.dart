import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum NivelEstado { bien, atencion, caido }

/// Resultado de revisar un servicio.
class ChequeoServicio {
  final String servicio;
  final NivelEstado nivel;
  final String detalle;

  /// Cuánto tardó en responder (null si no respondió).
  final int? milisegundos;

  const ChequeoServicio({
    required this.servicio,
    required this.nivel,
    required this.detalle,
    this.milisegundos,
  });
}

/// Dónde corre cada pieza en esta sesión del panel.
class EntornoPanel {
  final String proyecto;
  final bool emuladorFunctions;
  final bool emuladorStorage;

  const EntornoPanel({
    required this.proyecto,
    required this.emuladorFunctions,
    required this.emuladorStorage,
  });
}

abstract class SondaSistema {
  EntornoPanel get entorno;

  /// Revisa Firestore, Cloud Functions y Storage (en paralelo).
  Future<List<ChequeoServicio>> revisar();
}

/// Más que esto ya es "lento" para el panel.
const _lento = 1500;

class SondaSistemaFirebase implements SondaSistema {
  @override
  EntornoPanel get entorno => EntornoPanel(
    proyecto: Firebase.app().options.projectId,
    emuladorFunctions: const bool.fromEnvironment('EMULADOR_FUNCTIONS'),
    emuladorStorage: const bool.fromEnvironment('EMULADOR_STORAGE'),
  );

  @override
  Future<List<ChequeoServicio>> revisar() =>
      [_firestore(), _functions(), _storage()].wait;

  Future<ChequeoServicio> _firestore() async {
    final reloj = Stopwatch()..start();
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('academia')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      final ms = reloj.elapsedMilliseconds;
      return ChequeoServicio(
        servicio: 'Base de datos (Firestore)',
        nivel: ms > _lento ? NivelEstado.atencion : NivelEstado.bien,
        detalle: ms > _lento ? 'Responde, pero lento.' : 'Responde bien.',
        milisegundos: ms,
      );
    } catch (e) {
      return ChequeoServicio(
        servicio: 'Base de datos (Firestore)',
        nivel: NivelEstado.caido,
        detalle: 'No responde. Revisa la conexión a internet. ($e)',
      );
    }
  }

  Future<ChequeoServicio> _functions() async {
    const nombre = 'Funciones (Cloud Functions)';
    final reloj = Stopwatch()..start();
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable(
            'estadoSistema',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
          )
          .call<Map<Object?, Object?>>();
      final ms = reloj.elapsedMilliseconds;
      final gemini = r.data['gemini'] == true;
      return ChequeoServicio(
        servicio: nombre,
        nivel: gemini ? NivelEstado.bien : NivelEstado.atencion,
        detalle: gemini
            ? 'Responden. El tutor y el generador de preguntas tienen su clave.'
            : 'Responden, pero falta GEMINI_API_KEY: el tutor y el '
                  'generador de preguntas no funcionarán.',
        milisegundos: ms,
      );
    } catch (_) {
      return ChequeoServicio(
        servicio: nombre,
        nivel: NivelEstado.caido,
        detalle: entorno.emuladorFunctions
            ? 'El emulador no responde. Levántalo con '
                  'firebase emulators:start --only functions,storage.'
            : 'No responden. Sin el plan Blaze las funciones solo corren en '
                  'el emulador (abre el panel con '
                  '--dart-define=EMULADOR_FUNCTIONS=true).',
      );
    }
  }

  Future<ChequeoServicio> _storage() async {
    const nombre = 'Archivos (Storage)';
    final storage = FirebaseStorage.instance
      ..setMaxOperationRetryTime(const Duration(seconds: 8));
    final reloj = Stopwatch()..start();
    String? error;
    try {
      await storage
          .ref('estado/ping.txt')
          .getMetadata()
          .timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      // "No existe" o "sin permiso" también es una respuesta: Storage está.
      if (e.code != 'object-not-found' && e.code != 'unauthorized') {
        error = e.code;
      }
    } catch (e) {
      error = '$e';
    }
    if (error == null) {
      return ChequeoServicio(
        servicio: nombre,
        nivel: NivelEstado.bien,
        detalle: 'Responde. Se pueden subir imágenes y comprobantes.',
        milisegundos: reloj.elapsedMilliseconds,
      );
    }
    return ChequeoServicio(
      servicio: nombre,
      nivel: NivelEstado.caido,
      detalle: entorno.emuladorStorage
          ? 'El emulador no responde. Levántalo con '
                'firebase emulators:start --only functions,storage.'
          : 'No responde. Storage necesita el plan Blaze; mientras tanto '
                'usa el emulador (--dart-define=EMULADOR_STORAGE=true).',
    );
  }
}
