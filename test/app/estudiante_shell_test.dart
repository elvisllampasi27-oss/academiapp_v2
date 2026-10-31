import 'package:academiapp_v2/app/estudiante_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cambia de pestaña y construye cada una recien al abrirla', (
    tester,
  ) async {
    final indice = ValueNotifier(0);
    addTearDown(indice.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: EstudianteShell(
          indice: indice,
          pestanas: const [
            PestanaApp(
              etiqueta: 'Inicio',
              icono: Icons.home_outlined,
              contenido: Text('contenido inicio'),
            ),
            PestanaApp(
              etiqueta: 'Perfil',
              icono: Icons.person_outline,
              contenido: Text('contenido perfil'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('contenido inicio'), findsOneWidget);
    // La pestaña Perfil todavía no existe: no hace lecturas innecesarias.
    expect(find.text('contenido perfil', skipOffstage: false), findsNothing);

    await tester.tap(find.text('Perfil'));
    await tester.pump();

    expect(indice.value, 1);
    expect(find.text('contenido perfil'), findsOneWidget);
  });
}
