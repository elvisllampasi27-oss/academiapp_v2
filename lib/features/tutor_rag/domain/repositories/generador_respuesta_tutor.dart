import '../entities/contexto_tutor.dart';

abstract class GeneradorRespuestaTutor {
  Future<String> generar({required ContextoTutor contexto});
}
