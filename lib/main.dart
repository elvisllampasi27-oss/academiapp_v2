import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/dependencias.dart';
import 'firebase_options.dart';

/// Activa con: flutter run -d edge --dart-define=EMULADOR_FUNCTIONS=true
/// Las Cloud Functions se ejecutan en tu PC (firebase emulators:start);
/// Auth y Firestore siguen siendo los reales.
const _usarEmuladorFunctions = bool.fromEnvironment('EMULADOR_FUNCTIONS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode && _usarEmuladorFunctions) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  runApp(AcademiApp(dependencias: Dependencias.firebase()));
}
