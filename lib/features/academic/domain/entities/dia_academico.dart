import 'tema.dart';

class DiaAcademico {
  final int numero;
  final DateTime? fecha;
  final List<Tema> temas;

  const DiaAcademico({required this.numero, required this.temas, this.fecha});
}
