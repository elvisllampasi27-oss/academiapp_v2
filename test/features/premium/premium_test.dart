import 'dart:typed_data';

import 'package:academiapp_v2/features/premium/domain/compra_play.dart';
import 'package:academiapp_v2/features/premium/domain/configuracion_academia.dart';
import 'package:academiapp_v2/features/premium/domain/cupon.dart';
import 'package:academiapp_v2/features/premium/domain/pago.dart';
import 'package:academiapp_v2/features/premium/domain/repositorio_premium.dart';
import 'package:academiapp_v2/features/premium/presentation/premium_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tienda_falsa.dart';

final hoy = DateTime(2026, 11, 1, 10);

class RepositorioFalso implements RepositorioPremium {
  final enviados = <String>[];
  final cupones = <String, Cupon>{};
  DateTime? premiumHasta;
  var configuracion = const ConfiguracionAcademia(
    yapeNumero: '987654321',
    yapeTitular: 'Academia Prueba',
    whatsapp: '987654321',
  );
  final pagos = <Pago>[];

  @override
  Future<EstadoPremium> cargar(String uid) async => EstadoPremium(
    configuracion: configuracion,
    premiumHasta: premiumHasta,
    pagos: List.of(pagos),
  );

  @override
  Future<Cupon?> cupon(String codigo, DateTime ahora) async {
    final c = cupones[normalizarCodigo(codigo)];
    return c != null && c.vigente(ahora) ? c : null;
  }

  @override
  Future<void> enviarPago({
    required String uid,
    required String nombre,
    required String correo,
    required MetodoPago metodo,
    required String operacion,
    required int monto,
    String? cupon,
    Uint8List? foto,
  }) async {
    enviados.add('${metodo.name} $operacion S/ $monto ${cupon ?? ''}'.trim());
    pagos.add(
      Pago(
        id: idPago(
          metodo: metodo,
          operacion: operacion,
          uid: uid,
          cupon: cupon,
        ),
        usuarioId: uid,
        nombre: nombre,
        correo: correo,
        monto: monto,
        metodo: metodo,
        operacion: operacion,
        cupon: cupon,
        estado: EstadoPago.pendiente,
        creadoEn: hoy,
      ),
    );
  }
}

void main() {
  test('la prueba gratis se distingue de un Premium pagado', () {
    EstadoPremium estado(DateTime? hasta, DateTime? prueba) => EstadoPremium(
      configuracion: const ConfiguracionAcademia(),
      premiumHasta: hasta,
      pagos: const [],
      pruebaHasta: prueba,
    );
    final finPrueba = DateTime(2026, 12, 7);
    expect(estado(finPrueba, finPrueba).enPrueba, isTrue);
    // Pagó encima de la prueba: ya es Premium.
    expect(estado(DateTime(2027, 3, 7), finPrueba).enPrueba, isFalse);
    expect(estado(DateTime(2027, 3, 7), null).enPrueba, isFalse);
    expect(estado(null, null).enPrueba, isFalse);
  });

  group('cupón al aprobar un pago', () {
    Pago pago({MetodoPago metodo = MetodoPago.beca, String? cupon = 'UNSCH'}) {
      return Pago(
        id: 'p1',
        usuarioId: 'u1',
        nombre: 'Ana',
        correo: 'a@b.pe',
        monto: 0,
        metodo: metodo,
        operacion: '',
        cupon: cupon,
        estado: EstadoPago.pendiente,
        creadoEn: DateTime(2026, 11, 20),
      );
    }

    const beca = Cupon(
      codigo: 'UNSCH',
      tipo: TipoCupon.premiumGratis,
      usosMaximos: 3,
      usos: 2,
    );

    test('una beca con un cupón de Premium gratis vigente se aprueba', () {
      expect(problemaDeCupon(pago(), beca), isNull);
      expect(
        problemaDeCupon(pago(metodo: MetodoPago.yape, cupon: null), null),
        isNull,
      );
    });

    test('no se aprueba si el cupón no existe o no es de Premium gratis', () {
      expect(problemaDeCupon(pago(), null), contains('no existe'));
      expect(
        problemaDeCupon(
          pago(),
          const Cupon(codigo: 'UNSCH', tipo: TipoCupon.descuento, valor: 50),
        ),
        contains('no es de Premium gratis'),
      );
      expect(problemaDeCupon(pago(cupon: null), null), isNotNull);
    });

    test('no se aprueba si está desactivado, venció o se agotó', () {
      expect(
        problemaDeCupon(
          pago(),
          const Cupon(
            codigo: 'UNSCH',
            tipo: TipoCupon.premiumGratis,
            activo: false,
          ),
        ),
        contains('desactivado'),
      );
      expect(
        problemaDeCupon(
          pago(),
          Cupon(
            codigo: 'UNSCH',
            tipo: TipoCupon.premiumGratis,
            vence: DateTime(2026, 11, 1),
          ),
        ),
        contains('vencido'),
      );
      // Venció después de que lo envió: igual vale.
      expect(
        problemaDeCupon(
          pago(),
          Cupon(
            codigo: 'UNSCH',
            tipo: TipoCupon.premiumGratis,
            vence: DateTime(2026, 11, 22),
          ),
        ),
        isNull,
      );
      expect(
        problemaDeCupon(
          pago(),
          const Cupon(
            codigo: 'UNSCH',
            tipo: TipoCupon.premiumGratis,
            usosMaximos: 3,
            usos: 3,
          ),
        ),
        contains('3 veces'),
      );
    });

    test('con Yape, un cupón de descuento sirve', () {
      expect(
        problemaDeCupon(
          pago(metodo: MetodoPago.yape, cupon: 'BECA50'),
          const Cupon(codigo: 'BECA50', tipo: TipoCupon.descuento, valor: 50),
        ),
        isNull,
      );
    });
  });

  group('reglas de Premium', () {
    test('cupones: precio con descuento, precio fijo y beca', () {
      const descuento = Cupon(
        codigo: 'BECA50',
        tipo: TipoCupon.descuento,
        valor: 50,
      );
      const fijo = Cupon(
        codigo: 'LANZA',
        tipo: TipoCupon.precioFijo,
        valor: 19,
      );
      const beca = Cupon(codigo: 'UNSCH', tipo: TipoCupon.premiumGratis);
      expect(descuento.precioCon(29), 15);
      expect(fijo.precioCon(29), 19);
      expect(beca.precioCon(29), 0);
    });

    test('cupón vigente: activo, sin vencer y con usos', () {
      expect(
        Cupon(
          codigo: 'A',
          tipo: TipoCupon.descuento,
          vence: DateTime(2026, 10, 1),
        ).vigente(hoy),
        isFalse,
      );
      expect(
        const Cupon(
          codigo: 'A',
          tipo: TipoCupon.descuento,
          usosMaximos: 5,
          usos: 5,
        ).vigente(hoy),
        isFalse,
      );
      expect(
        const Cupon(
          codigo: 'A',
          tipo: TipoCupon.descuento,
          activo: false,
        ).vigente(hoy),
        isFalse,
      );
      expect(
        const Cupon(codigo: 'A', tipo: TipoCupon.descuento).vigente(hoy),
        isTrue,
      );
      expect(normalizarCodigo(' beca 50 '), 'BECA50');
    });

    test('Premium se suma a lo que le queda', () {
      expect(
        premiumNuevoHasta(null, hoy, 90),
        hoy.add(const Duration(days: 90)),
      );
      final vigente = DateTime(2026, 11, 11);
      expect(
        premiumNuevoHasta(vigente, hoy, 90),
        vigente.add(const Duration(days: 90)),
      );
      expect(esPremium(vigente, hoy), isTrue);
      expect(esPremium(DateTime(2026, 10, 31), hoy), isFalse);
    });

    test('N.º de operación, id del pago y configuración por defecto', () {
      expect(operacionValida('00-45812'), isTrue); // 7 dígitos
      expect(operacionValida('12345'), isFalse);
      expect(normalizarOperacion('N.º 00-458129'), '00458129');
      expect(
        idPago(metodo: MetodoPago.yape, operacion: '0045 8129', uid: 'u'),
        'yape__00458129',
      );
      expect(
        idPago(
          metodo: MetodoPago.beca,
          operacion: '',
          uid: 'u',
          cupon: 'UNSCH',
        ),
        'beca__u__UNSCH',
      );
      final c = ConfiguracionAcademia.desdeMapa({'precio': 35});
      expect((c.precio, c.diasPremium, c.tutorGratis), (35, 90, 3));
      expect(
        enlaceWhatsapp('987 654 321', 'Hola').toString(),
        'https://wa.me/51987654321?text=Hola',
      );
    });
  });

  testWidgets('Premium: paga con cupón y queda en revisión', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repositorio = RepositorioFalso()
      ..cupones['BECA50'] = const Cupon(
        codigo: 'BECA50',
        tipo: TipoCupon.descuento,
        valor: 50,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: PremiumPage(
          uid: 'ana',
          nombre: 'Ana',
          correo: 'ana@mail.pe',
          repositorio: repositorio,
          abrirEnlace: (_) async => true,
          ahora: () => hoy,
          canal: CanalCompra.web,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan gratis'), findsOneWidget);
    expect(find.text('987654321'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Cupón o beca (opcional)'),
      'beca50',
    );
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Paga S/ 15 por Yape o Plin'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'N.º de operación'),
      '0045812',
    );
    await tester.ensureVisible(find.text('Enviar pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar pago'));
    await tester.pumpAndSettle();

    expect(repositorio.enviados, ['yape 0045812 S/ 15 BECA50']);
    expect(find.text('Tu pago está en revisión'), findsOneWidget);
    expect(find.text('Enviar captura por WhatsApp'), findsOneWidget);
  });

  group('Premium en Google Play', () {
    Future<void> abrir(
      WidgetTester tester,
      RepositorioFalso repositorio, {
      ServicioCompraPlay? compra,
    }) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumPage(
            uid: 'ana',
            nombre: 'Ana',
            correo: 'ana@mail.pe',
            repositorio: repositorio,
            abrirEnlace: (_) async => true,
            ahora: () => hoy,
            canal: CanalCompra.googlePlay,
            compraPlay: compra,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ServicioCompraPlay servicio(
      TiendaFalsa tienda,
      RepositorioFalso repositorio, {
      bool activa = true,
    }) => ServicioCompraPlay(
      tienda: tienda,
      verificar: (_, _) async {
        if (activa) {
          repositorio.premiumHasta = hoy.add(const Duration(days: 90));
        }
        return (activada: activa, consumida: true);
      },
    );

    FilledButton boton(WidgetTester tester) => tester.widget<FilledButton>(
      find.byWidgetPredicate((w) => w is FilledButton),
    );

    testWidgets('no muestra Yape, cupones ni pagos; sin tienda, apagado', (
      tester,
    ) async {
      final repositorio = RepositorioFalso();
      await repositorio.enviarPago(
        uid: 'ana',
        nombre: 'Ana',
        correo: 'ana@mail.pe',
        metodo: MetodoPago.yape,
        operacion: '0045812',
        monto: 35,
      );
      await abrir(tester, repositorio);

      expect(find.text('987654321'), findsNothing);
      expect(find.textContaining('Yape'), findsNothing);
      expect(find.text('Cupón o beca (opcional)'), findsNothing);
      expect(find.text('Mis pagos'), findsNothing);
      expect(find.text('Tu pago está en revisión'), findsNothing);
      expect(find.textContaining('S/'), findsNothing);
      expect(find.text('Premium por 90 días'), findsOneWidget);
      expect(find.text('Obtener Premium'), findsOneWidget);
      expect(boton(tester).onPressed, isNull);
      expect(find.text('La compra estará disponible pronto.'), findsOneWidget);
    });

    testWidgets('el producto aún no existe en Google Play: apagado', (
      tester,
    ) async {
      final repositorio = RepositorioFalso();
      final tienda = TiendaFalsa()..disponible = null;
      await abrir(tester, repositorio, compra: servicio(tienda, repositorio));
      expect(boton(tester).onPressed, isNull);
      expect(find.text('La compra estará disponible pronto.'), findsOneWidget);
    });

    testWidgets('compra con el precio de Google Play y queda Premium', (
      tester,
    ) async {
      final repositorio = RepositorioFalso();
      final tienda = TiendaFalsa();
      await abrir(tester, repositorio, compra: servicio(tienda, repositorio));

      expect(find.text('Premium: S/ 35.00 por 90 días'), findsOneWidget);
      expect(find.textContaining('política de Google Play'), findsOneWidget);
      await tester.tap(find.text('Obtener Premium · S/ 35.00'));
      await tester.pumpAndSettle();

      expect(tienda.cuentas, [cuentaOfuscadaPlay('ana')]);
      expect(find.text('¡Listo! Ya tienes Premium.'), findsOneWidget);
      expect(find.text('Eres Premium'), findsOneWidget);
    });

    testWidgets('pago pendiente: lo avisa', (tester) async {
      final repositorio = RepositorioFalso();
      final tienda = TiendaFalsa()..respuesta = EstadoCompraTienda.pendiente;
      await abrir(tester, repositorio, compra: servicio(tienda, repositorio));
      await tester.tap(find.text('Obtener Premium · S/ 35.00'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tu pago está pendiente en Google Play'),
        findsOneWidget,
      );
      expect(find.text('Plan gratis'), findsOneWidget);
    });

    testWidgets('cancelar no muestra error; si falla, avisa', (tester) async {
      final repositorio = RepositorioFalso();
      final tienda = TiendaFalsa()..respuesta = EstadoCompraTienda.cancelada;
      await abrir(tester, repositorio, compra: servicio(tienda, repositorio));
      await tester.tap(find.text('Obtener Premium · S/ 35.00'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo'), findsNothing);
      expect(find.textContaining('Google Play no pudo'), findsNothing);

      tienda.respuesta = EstadoCompraTienda.error;
      await tester.tap(find.text('Obtener Premium · S/ 35.00'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Google Play no pudo completar la compra. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
    });
  });
}
