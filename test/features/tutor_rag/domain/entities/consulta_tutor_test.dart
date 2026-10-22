import 'package:academiapp_v2/features/tutor_rag/domain/entities/consulta_tutor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('una consulta conserva estudiante habilidad y pregunta', () {
    const consulta = ConsultaTutor(
      matriculaId: 'matricula-1',
      habilidadId: 'suma-matrices',
      pregunta: 'No entiendo como sumar dos matrices.',
    );

    expect(consulta.matriculaId, 'matricula-1');
    expect(consulta.habilidadId, 'suma-matrices');
    expect(consulta.pregunta, 'No entiendo como sumar dos matrices.');
  });
}
