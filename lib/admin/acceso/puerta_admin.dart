import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/presentation/colores_app.dart';

/// Acceso al panel: solo cuentas con el permiso `admin` (custom claim,
/// se asigna con tool/hacer_admin.js). Las reglas de Firestore exigen el
/// mismo permiso, así que ocultar el panel no es la única barrera.
abstract class AccesoAdmin {
  /// Correo del administrador con sesión, o null.
  Stream<String?> get administrador;

  /// Lanza [StateError] con un mensaje si no se pudo o no es admin.
  Future<void> entrar({required String correo, required String contrasena});

  Future<void> entrarConGoogle();

  Future<void> salir();
}

class AccesoAdminFirebase implements AccesoAdmin {
  final FirebaseAuth auth;

  AccesoAdminFirebase(this.auth);

  @override
  Stream<String?> get administrador =>
      auth.idTokenChanges().asyncMap((u) async {
        if (u == null) return null;
        final token = await u.getIdTokenResult();
        return token.claims?['admin'] == true ? (u.email ?? u.uid) : null;
      });

  Future<void> _exigirAdmin() async {
    final token = await auth.currentUser?.getIdTokenResult(true);
    if (token?.claims?['admin'] != true) {
      await auth.signOut();
      throw StateError('Esta cuenta no tiene permiso de administrador.');
    }
  }

  @override
  Future<void> entrar({
    required String correo,
    required String contrasena,
  }) async {
    try {
      await auth.signInWithEmailAndPassword(
        email: correo,
        password: contrasena,
      );
    } on FirebaseAuthException {
      throw StateError('Correo o contraseña incorrectos.');
    }
    await _exigirAdmin();
  }

  @override
  Future<void> entrarConGoogle() async {
    try {
      await auth.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException {
      throw StateError('No se pudo entrar con Google.');
    }
    await _exigirAdmin();
  }

  @override
  Future<void> salir() => auth.signOut();
}

class PuertaAdmin extends StatelessWidget {
  final AccesoAdmin acceso;
  final Widget Function(String correo, VoidCallback salir) panel;

  const PuertaAdmin({super.key, required this.acceso, required this.panel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: acceso.administrador,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final correo = snapshot.data;
        if (correo == null) return _LoginAdmin(acceso: acceso);
        return panel(correo, acceso.salir);
      },
    );
  }
}

class _LoginAdmin extends StatefulWidget {
  final AccesoAdmin acceso;

  const _LoginAdmin({required this.acceso});

  @override
  State<_LoginAdmin> createState() => _LoginAdminState();
}

class _LoginAdminState extends State<_LoginAdmin> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _intentar(Future<void> Function() accion) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await accion();
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Panel de AcademiApp',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Solo administradores.',
                      style: TextStyle(color: ColoresApp.apagado),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _correo,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contrasena,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _intentar(
                        () => widget.acceso.entrar(
                          correo: _correo.text.trim(),
                          contrasena: _contrasena.text,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: ColoresApp.naranja),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _cargando
                          ? null
                          : () => _intentar(
                              () => widget.acceso.entrar(
                                correo: _correo.text.trim(),
                                contrasena: _contrasena.text,
                              ),
                            ),
                      child: const Text('Entrar'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _cargando
                          ? null
                          : () => _intentar(widget.acceso.entrarConGoogle),
                      child: const Text('Entrar con Google'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
