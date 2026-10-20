import 'package:flutter_test/flutter_test.dart';
import 'package:academiapp_v2/app/app.dart';

void main() {
  testWidgets('AcademiApp smoke test', (WidgetTester tester) async {
    // Renderiza el widget principal de la app
    await tester.pumpWidget(const AcademiApp());

    // Comprueba que el texto de bienvenida esté en pantalla
    expect(find.text('AcademiApp V2'), findsOneWidget);
  });
}
