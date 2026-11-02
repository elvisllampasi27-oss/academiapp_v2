import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin/app_admin.dart';
import 'firebase_options.dart';

/// Panel de control (web). Se ejecuta con:
///   flutter run -d edge -t lib/main_admin.dart
/// Para generar quizzes con IA en tu PC (firebase emulators:start):
///   flutter run -d edge -t lib/main_admin.dart --dart-define=EMULADOR_FUNCTIONS=true
const _usarEmuladorFunctions = bool.fromEnvironment('EMULADOR_FUNCTIONS');

/// Imágenes en el emulador de Storage (para probar sin el plan Blaze):
///   firebase emulators:start --only functions,storage
///   ... --dart-define=EMULADOR_STORAGE=true
const _usarEmuladorStorage = bool.fromEnvironment('EMULADOR_STORAGE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode && _usarEmuladorFunctions) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }
  if (kDebugMode && _usarEmuladorStorage) {
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  runApp(const AppAdmin());
}
