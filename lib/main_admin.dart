import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin/app_admin.dart';
import 'firebase_options.dart';

/// Panel de control (web). Se ejecuta con:
///   flutter run -d edge -t lib/main_admin.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AppAdmin());
}
