enum TipoCupon {
  descuento('% de descuento'),
  precioFijo('Precio fijo'),
  premiumGratis('Premium gratis');

  final String etiqueta;
  const TipoCupon(this.etiqueta);
}

/// Cupón o beca (documento `cupones/{CODIGO}`).
class Cupon {
  final String codigo;
  final TipoCupon tipo;

  /// % para descuento, soles para precio fijo; no se usa en premium gratis.
  final int valor;
  final int? usosMaximos;
  final int usos;
  final DateTime? vence;
  final bool activo;

  const Cupon({
    required this.codigo,
    required this.tipo,
    this.valor = 0,
    this.usosMaximos,
    this.usos = 0,
    this.vence,
    this.activo = true,
  });

  bool vigente(DateTime ahora) =>
      activo &&
      (vence == null || !vence!.isBefore(ahora)) &&
      (usosMaximos == null || usos < usosMaximos!);

  /// Lo que paga el estudiante con este cupón.
  int precioCon(int precio) => switch (tipo) {
    TipoCupon.descuento => (precio * (100 - valor.clamp(0, 100)) / 100).round(),
    TipoCupon.precioFijo => valor.clamp(0, precio).toInt(),
    TipoCupon.premiumGratis => 0,
  };

  String get beneficio => switch (tipo) {
    TipoCupon.descuento => '$valor % de descuento',
    TipoCupon.precioFijo => 'Paga S/ $valor',
    TipoCupon.premiumGratis => 'Premium gratis',
  };
}

/// "beca 50 " -> "BECA50". Solo letras, números y guiones.
String normalizarCodigo(String codigo) =>
    codigo.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
