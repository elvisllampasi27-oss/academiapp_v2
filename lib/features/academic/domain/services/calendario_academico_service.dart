import '../entities/dia_academico.dart';
import '../entities/tema.dart';

class CalendarioAcademicoService {
  const CalendarioAcademicoService();

  List<DiaAcademico> generar(List<Tema> secuencia) {
    final dias = <DiaAcademico>[];

    var posicion = 0;
    var numeroDia = 1;

    while (posicion < secuencia.length) {
      final posicionSemana = (numeroDia - 1) % 6;

      final cantidadTemas = posicionSemana == 5 ? 2 : 3;

      final fin = (posicion + cantidadTemas < secuencia.length)
          ? posicion + cantidadTemas
          : secuencia.length;

      dias.add(
        DiaAcademico(
          numero: numeroDia,
          temas: secuencia.sublist(posicion, fin),
        ),
      );

      posicion = fin;
      numeroDia++;
    }

    return dias;
  }
}
