import 'dart:math' as math;

import '../entities/progreso_clase.dart';

/// Reglas para saber cuánto de la clase vio el estudiante.
///
/// Cuenta los segundos realmente vistos (en cualquier orden): adelantar el
/// video no suma, pero lo que se vea después del salto sí. La clase se
/// completa al haber visto el 90 %.
class SeguimientoClase {
  /// Separación máxima (segundos) entre dos lecturas seguidas del
  /// reproductor para considerar que se vio y no se adelantó.
  static const saltoMaximo = 3.0;
  static const umbralCompleta = 0.9;

  /// A partir de cuántos segundos por delante de lo pendiente se avisa
  /// que se saltó una parte.
  static const margenAviso = 5.0;

  final List<(double, double)> _tramos;
  double _duracion;
  double? _ultimaPosicion;
  bool _completada;

  SeguimientoClase({
    List<(double, double)> tramos = const [],
    double duracion = 0,
    bool completada = false,
  }) : _tramos = [...tramos]..sort((a, b) => a.$1.compareTo(b.$1)),
       _duracion = duracion,
       _completada = completada;

  factory SeguimientoClase.desde(ProgresoClase? progreso) => SeguimientoClase(
    tramos: progreso?.tramos ?? const [],
    duracion: progreso?.duracion ?? 0,
    completada: progreso?.completada ?? false,
  );

  List<(double, double)> get tramos => List.unmodifiable(_tramos);
  double get duracion => _duracion;
  bool get completada => _completada;
  double get posicionActual => _ultimaPosicion ?? 0;

  /// Segundos vistos.
  double get visto => _tramos.fold(0, (suma, t) => suma + (t.$2 - t.$1));

  /// De 0 a 1.
  double get fraccion {
    if (_completada) return 1;
    if (_duracion <= 0) return 0;
    return (visto / _duracion).clamp(0.0, 1.0);
  }

  /// Primer segundo que falta ver (null si no falta nada).
  double? get pendienteDesde {
    var cursor = 0.0;

    for (final (desde, hasta) in _tramos) {
      if (desde > cursor + saltoMaximo) return cursor;
      cursor = math.max(cursor, hasta);
    }

    if (_duracion > 0 && cursor >= _duracion - saltoMaximo) return null;
    return cursor;
  }

  /// Si el estudiante está más adelante de una parte que no vio, desde
  /// dónde se la saltó (para ofrecerle volver). Null si no aplica.
  double? get saltadoDesde {
    if (_completada) return null;
    final pendiente = pendienteDesde;
    if (pendiente == null) return null;
    return posicionActual > pendiente + margenAviso ? pendiente : null;
  }

  /// Desde dónde continuar al volver a abrir la clase.
  double get continuarDesde => _completada ? 0 : (pendienteDesde ?? 0);

  /// Registra una lectura del reproductor. Devuelve true si aumentó lo visto.
  bool registrar({required double posicion, required double duracion}) {
    if (duracion > 0) _duracion = duracion;

    final anterior = _ultimaPosicion;
    _ultimaPosicion = posicion;
    if (anterior == null) return false;

    final avance = posicion - anterior;
    // Pausa, retroceso o salto: no se vio nada nuevo.
    if (avance <= 0 || avance > saltoMaximo) return false;

    final antes = visto;
    _agregar(anterior, posicion);

    if (!_completada && _duracion > 0 && visto >= _duracion * umbralCompleta) {
      _completada = true;
    }

    return visto > antes;
  }

  /// Agrega un tramo visto y une los que se tocan.
  void _agregar(double desde, double hasta) {
    final todos = [..._tramos, (desde, hasta)]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final unidos = <(double, double)>[];

    for (final tramo in todos) {
      if (unidos.isNotEmpty && tramo.$1 <= unidos.last.$2 + 0.5) {
        final ultimo = unidos.removeLast();
        unidos.add((ultimo.$1, math.max(ultimo.$2, tramo.$2)));
      } else {
        unidos.add(tramo);
      }
    }

    _tramos
      ..clear()
      ..addAll(unidos);
  }

  ProgresoClase aProgreso({required String temaId, required String versionId}) {
    return ProgresoClase(
      temaId: temaId,
      versionId: versionId,
      tramos: tramos,
      duracion: _duracion,
      completada: _completada,
    );
  }
}
