import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencias.dart';
import 'firebase_options.dart';

/// Activa con: flutter run -d edge --dart-define=EMULADOR_FUNCTIONS=true
/// Las Cloud Functions se ejecutan en tu PC (firebase emulators:start);
/// Auth y Firestore siguen siendo los reales.
const _usarEmuladorFunctions = bool.fromEnvironment('EMULADOR_FUNCTIONS');

/// Imágenes en el emulador de Storage (para probar sin el plan Blaze):
///   firebase emulators:start --only functions,storage
///   ... --dart-define=EMULADOR_STORAGE=true
const _usarEmuladorStorage = bool.fromEnvironment('EMULADOR_STORAGE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode && _usarEmuladorFunctions) {
    // 127.0.0.1 y no "localhost": en Windows "localhost" puede ir por IPv6
    // (::1) y el emulador solo escucha en IPv4.
    FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
  }
  if (kDebugMode && _usarEmuladorStorage) {
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
  }

  runApp(AcademiApp(dependencias: Dependencias.firebase()));
}
