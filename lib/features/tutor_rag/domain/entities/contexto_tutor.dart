import '../../../adaptive_engine/domain/entities/recomendacion.dart';
import '../../../student_model/domain/entities/estado_dominio.dart';
import 'chunk_conocimiento.dart';
import 'consulta_tutor.dart';

class ContextoTutor {
  final ConsultaTutor consulta;
  final EstadoDominio estadoDominio;
  final Recomendacion recomendacion;
  final List<ChunkConocimiento> chunks;

  const ContextoTutor({
    required this.consulta,
    required this.estadoDominio,
    required this.recomendacion,
    required this.chunks,
  });
}
