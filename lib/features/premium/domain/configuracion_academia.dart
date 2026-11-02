/// Reglas generales de la academia (documento `config/academia`). Las edita
/// el administrador en el panel; la app y el servidor las leen.
class ConfiguracionAcademia {
  /// Precio de Premium en soles.
  final int precio;
  final int diasPremium;

  final String yapeNumero;
  final String yapeTitular;
  final String whatsapp;

  /// Foto del comprobante desde la app. Necesita Firebase Storage
  /// (plan Blaze); mientras tanto la foto se manda por WhatsApp.
  final bool fotoComprobante;

  final int tutorGratis;
  final int tutorPremium;
  final bool simulacroSoloPremium;

  const ConfiguracionAcademia({
    this.precio = 29,
    this.diasPremium = 90,
    this.yapeNumero = '',
    this.yapeTitular = '',
    this.whatsapp = '',
    this.fotoComprobante = false,
    this.tutorGratis = 3,
    this.tutorPremium = 20,
    this.simulacroSoloPremium = true,
  });

  factory ConfiguracionAcademia.desdeMapa(Map<String, dynamic>? m) {
    const d = ConfiguracionAcademia();
    if (m == null) return d;
    int entero(String k, int defecto) => (m[k] as num?)?.toInt() ?? defecto;
    String texto(String k) => (m[k] as String?)?.trim() ?? '';
    bool logico(String k, bool defecto) =>
        m[k] is bool ? m[k] as bool : defecto;
    return ConfiguracionAcademia(
      precio: entero('precio', d.precio),
      diasPremium: entero('diasPremium', d.diasPremium),
      yapeNumero: texto('yapeNumero'),
      yapeTitular: texto('yapeTitular'),
      whatsapp: texto('whatsapp'),
      fotoComprobante: logico('fotoComprobante', d.fotoComprobante),
      tutorGratis: entero('tutorGratis', d.tutorGratis),
      tutorPremium: entero('tutorPremium', d.tutorPremium),
      simulacroSoloPremium: logico(
        'simulacroSoloPremium',
        d.simulacroSoloPremium,
      ),
    );
  }

  Map<String, Object> aMapa() => {
    'precio': precio,
    'diasPremium': diasPremium,
    'yapeNumero': yapeNumero,
    'yapeTitular': yapeTitular,
    'whatsapp': whatsapp,
    'fotoComprobante': fotoComprobante,
    'tutorGratis': tutorGratis,
    'tutorPremium': tutorPremium,
    'simulacroSoloPremium': simulacroSoloPremium,
  };
}

bool esPremium(DateTime? premiumHasta, DateTime ahora) =>
    premiumHasta != null && premiumHasta.isAfter(ahora);

/// Nuevo vencimiento: si todavía es Premium, se suma a lo que le queda.
DateTime premiumNuevoHasta(DateTime? actual, DateTime ahora, int dias) {
  final base = actual != null && actual.isAfter(ahora) ? actual : ahora;
  return base.add(Duration(days: dias));
}
