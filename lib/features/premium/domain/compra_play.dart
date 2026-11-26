import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Producto único de Google Play (no suscripción): 90 días de Premium.
/// Se crea con este mismo id en Play Console → Productos integrados.
const productoPremiumPlay = 'premium_90_dias';

/// Cuenta que se manda a Google Play con la compra, para que el servidor
/// compruebe que el token es de este alumno. Sin datos personales. Debe
/// coincidir con cuentaOfuscada() de functions/src/premium/compra_play.js.
String cuentaOfuscadaPlay(String uid) =>
    sha256.convert(utf8.encode('sinchi:$uid')).toString();

class ProductoPlay {
  final String id;

  /// Como lo muestra Google Play, con moneda ("S/ 35.00").
  final String precio;

  const ProductoPlay({required this.id, required this.precio});
}

enum EstadoCompraTienda { pendiente, comprada, restaurada, cancelada, error }

/// Una compra tal como la avisa la tienda.
class CompraTienda {
  final String productoId;

  /// Token de compra de Google Play (lo verifica el servidor).
  final String token;
  final EstadoCompraTienda estado;

  /// Falta confirmarla ante la tienda (completePurchase).
  final bool porCompletar;

  /// El objeto del plugin, para confirmarla.
  final Object? original;

  const CompraTienda({
    required this.productoId,
    required this.token,
    required this.estado,
    this.porCompletar = false,
    this.original,
  });
}

/// La tienda del teléfono. En Android: in_app_purchase (TiendaGooglePlay).
abstract class TiendaPlay {
  /// Compras nuevas, pendientes que se confirman y restauradas.
  Stream<List<CompraTienda>> get compras;

  /// null si la tienda no está disponible o el producto no existe.
  Future<ProductoPlay?> producto(String id);

  /// Abre la hoja de pago de Google Play. El resultado llega por [compras].
  Future<void> comprar(String productoId, {required String cuenta});

  /// Vuelve a mandar por [compras] las compras que no se terminaron.
  Future<void> restaurar();

  Future<void> completar(CompraTienda compra);
}

/// Respuesta del servidor (verificarCompraPlay).
typedef VerificacionPlay = ({bool activada, bool consumida});

typedef VerificarCompraPlay =
    Future<VerificacionPlay> Function(String productoId, String token);

/// { estado: 'activada' | 'pendiente', consumida } de verificarCompraPlay.
VerificacionPlay verificacionDesdeMapa(Map<Object?, Object?> datos) => (
  activada: datos['estado'] == 'activada',
  consumida: datos['consumida'] == true,
);

class ExcepcionCompraPlay implements Exception {
  final String mensaje;

  /// El alumno cerró la hoja de pago: no hay que mostrar error.
  final bool cancelada;

  const ExcepcionCompraPlay(this.mensaje, {this.cancelada = false});

  @override
  String toString() => mensaje;
}

/// Mensaje para el alumno según el error de verificarCompraPlay. Los
/// mensajes del servidor ya vienen en español para estos códigos.
String mensajeErrorCompra(String codigo, String? mensaje) {
  const delServidor = {
    'permission-denied',
    'not-found',
    'failed-precondition',
    'unavailable',
  };
  if (delServidor.contains(codigo) && mensaje != null && mensaje.isNotEmpty) {
    return mensaje;
  }
  if (codigo == 'unauthenticated') return 'Inicia sesión otra vez.';
  return 'No pudimos confirmar tu compra. Inténtalo en un rato.';
}

enum ResultadoCompra { activada, pendiente }

/// Compra de Premium con Google Play: abre la tienda, manda el token al
/// servidor y confirma la compra. Escucha la tienda desde que se crea, así
/// que también termina compras que quedaron a medias (app cerrada a mitad
/// de la compra o pago pendiente que se confirmó después).
class ServicioCompraPlay {
  final TiendaPlay tienda;
  final VerificarCompraPlay verificar;

  late final StreamSubscription<List<CompraTienda>> _suscripcion;
  final _activaciones = StreamController<void>.broadcast();
  Completer<ResultadoCompra>? _enCurso;

  ServicioCompraPlay({required this.tienda, required this.verificar}) {
    _suscripcion = tienda.compras.listen(_alLlegar);
  }

  /// Avisa cada vez que una compra activó Premium.
  Stream<void> get activaciones => _activaciones.stream;

  Future<ProductoPlay?> cargarProducto() async {
    try {
      return await tienda.producto(productoPremiumPlay);
    } catch (_) {
      return null;
    }
  }

  /// Termina cuando Google Play y el servidor confirman la compra, o cuando
  /// queda pendiente. Lanza [ExcepcionCompraPlay] si se cancela o falla.
  Future<ResultadoCompra> comprar(String uid) async {
    if (_enCurso case final c?) return c.future;
    final enCurso = Completer<ResultadoCompra>();
    _enCurso = enCurso;
    try {
      await tienda.comprar(productoPremiumPlay, cuenta: cuentaOfuscadaPlay(uid));
    } catch (_) {
      _fallar(const ExcepcionCompraPlay('No se pudo abrir Google Play.'));
    }
    return enCurso.future;
  }

  /// Al entrar a la app: termina compras que quedaron sin confirmar.
  Future<void> revisarPendientes() async {
    try {
      await tienda.restaurar();
    } catch (_) {}
  }

  Future<void> cerrar() async {
    await _suscripcion.cancel();
    await _activaciones.close();
  }

  Future<void> _alLlegar(List<CompraTienda> compras) async {
    for (final compra in compras) {
      if (compra.productoId != productoPremiumPlay) continue;
      switch (compra.estado) {
        case EstadoCompraTienda.pendiente:
          _terminar(ResultadoCompra.pendiente);
        case EstadoCompraTienda.cancelada:
          _fallar(const ExcepcionCompraPlay('Compra cancelada.', cancelada: true));
        case EstadoCompraTienda.error:
          _fallar(
            const ExcepcionCompraPlay(
              'Google Play no pudo completar la compra. Inténtalo de nuevo.',
            ),
          );
        case EstadoCompraTienda.comprada || EstadoCompraTienda.restaurada:
          await _activar(compra);
      }
    }
  }

  Future<void> _activar(CompraTienda compra) async {
    final VerificacionPlay resultado;
    try {
      resultado = await verificar(compra.productoId, compra.token);
    } on ExcepcionCompraPlay catch (e) {
      _fallar(e);
      return;
    } catch (_) {
      _fallar(
        const ExcepcionCompraPlay(
          'No pudimos confirmar tu compra. Inténtalo en un rato.',
        ),
      );
      return;
    }
    if (!resultado.activada) {
      _terminar(ResultadoCompra.pendiente);
      return;
    }
    // Si el servidor ya la consumió, Google la da por confirmada.
    if (compra.porCompletar && !resultado.consumida) {
      try {
        await tienda.completar(compra);
      } catch (_) {}
    }
    if (!_activaciones.isClosed) _activaciones.add(null);
    _terminar(ResultadoCompra.activada);
  }

  void _terminar(ResultadoCompra resultado) {
    final c = _enCurso;
    _enCurso = null;
    if (c != null && !c.isCompleted) c.complete(resultado);
  }

  void _fallar(ExcepcionCompraPlay error) {
    final c = _enCurso;
    _enCurso = null;
    if (c != null && !c.isCompleted) c.completeError(error);
  }
}
