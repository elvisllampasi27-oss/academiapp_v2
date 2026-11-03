import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado de un estudiante en un examen semanal.
class ResultadoSemanal {
  final String uid;
  final String nombre;
  final int puntaje;
  final int correctas;
  final int total;
  final int segundos;
  final DateTime terminado;

  const ResultadoSemanal({
    required this.uid,
    required this.nombre,
    required this.puntaje,
    required this.correctas,
    required this.total,
    required this.segundos,
    required this.terminado,
  });
}

/// Mismo orden que en Cloud Functions: más puntaje, menos tiempo y, si
/// empatan, quien terminó antes. Devuelve (puesto, resultado).
List<(int, ResultadoSemanal)> ordenarRanking(List<ResultadoSemanal> lista) {
  final orden = [...lista]
    ..sort((a, b) {
      final p = b.puntaje.compareTo(a.puntaje);
      if (p != 0) return p;
      final t = a.segundos.compareTo(b.segundos);
      return t != 0 ? t : a.terminado.compareTo(b.terminado);
    });
  return [for (final (i, r) in orden.indexed) (i + 1, r)];
}

/// "12:34".
String duracionBreve(int segundos) =>
    '${segundos ~/ 60}:${(segundos % 60).toString().padLeft(2, '0')}';

abstract class RepositorioRankingAdmin {
  /// Los que ya dieron ese examen semanal.
  Future<List<ResultadoSemanal>> resultados(String examenId);
}

class RepositorioRankingAdminFirestore implements RepositorioRankingAdmin {
  final FirebaseFirestore db;

  RepositorioRankingAdminFirestore({FirebaseFirestore? firestore})
    : db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ResultadoSemanal>> resultados(String examenId) async {
    final q = await db
        .collection('simulacros')
        .where('examenSemanalId', isEqualTo: examenId)
        .where('estado', isEqualTo: 'completado')
        .get();
    return [
      for (final d in q.docs)
        if (d.data() case {
          'usuarioId': final String uid,
          'terminadoEn': final Timestamp fin,
        })
          ResultadoSemanal(
            uid: uid,
            nombre: (d.data()['nombre'] as String?) ?? '',
            puntaje: (d.data()['puntaje'] as num?)?.toInt() ?? 0,
            correctas: (d.data()['correctas'] as num?)?.toInt() ?? 0,
            total: (d.data()['total'] as num?)?.toInt() ?? 0,
            segundos: (d.data()['tiempoUsadoSegundos'] as num?)?.toInt() ?? 0,
            terminado: fin.toDate(),
          ),
    ];
  }
}
