import '../domain/entities/examen.dart';
import '../domain/entities/simulacro.dart';

String _texto(Object? v) => v is String ? v : '';
String? _opcional(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _entero(Object? v) => v is num ? v.toInt() : 0;
List<Object?> _lista(Object? v) => v is List ? v : const [];
Map<Object?, Object?> _mapa(Object? v) => v is Map ? v : const {};

ExamenPasado? examenDesdeMapa(String id, Map<String, dynamic> datos) {
  final tipo = TipoExamen.values.asNameMap()[datos['tipo']];
  final fecha = DateTime.tryParse(_texto(datos['fecha']));
  if (tipo == null || fecha == null) return null;

  return ExamenPasado(
    id: id,
    tipo: tipo,
    fecha: fecha,
    titulo: _texto(datos['titulo']),
    totalPreguntas: _entero(datos['totalPreguntas']),
    secciones: [
      for (final s in _lista(datos['secciones']).map(_mapa))
        SeccionExamen(nombre: _texto(s['nombre']), total: _entero(s['total'])),
    ],
  );
}

PreguntaExamen preguntaDesdeMapa(String id, Map<Object?, Object?> datos) {
  return PreguntaExamen(
    id: id,
    numero: _entero(datos['numero']),
    seccion: _texto(datos['seccion']),
    enunciado: _texto(datos['enunciado']),
    opciones: [
      for (final o in _lista(datos['opciones']).map(_mapa))
        OpcionExamen(id: _texto(o['id']), texto: _texto(o['texto'])),
    ],
    imagen: _opcional(datos['imagen']),
  );
}

RevisionPregunta revisionDesdeMapa(Map<Object?, Object?> datos) {
  return RevisionPregunta(
    esCorrecta: datos['esCorrecta'] == true,
    opcionCorrectaId: _texto(datos['opcionCorrectaId']),
    solucion: _opcional(datos['solucion']),
    imagenSolucion: _opcional(datos['imagenSolucion']),
  );
}

Simulacro simulacroDesdeMapa(Map<Object?, Object?> datos) {
  return Simulacro(
    id: _texto(datos['simulacroId']),
    duracionSegundos: _entero(datos['duracionSegundos']),
    vence: DateTime.fromMillisecondsSinceEpoch(_entero(datos['venceEnMs'])),
    preguntas: [
      for (final p in _lista(datos['preguntas']).map(_mapa))
        preguntaDesdeMapa(_texto(p['id']), p),
    ],
  );
}

ResultadoSimulacro resultadoDesdeMapa(Map<Object?, Object?> datos) {
  return ResultadoSimulacro(
    correctas: _entero(datos['correctas']),
    total: _entero(datos['total']),
    puntaje: _entero(datos['puntaje']),
    tiempoUsadoSegundos: _entero(datos['tiempoUsadoSegundos']),
    porSeccion: [
      for (final s in _lista(datos['porSeccion']).map(_mapa))
        ResultadoSeccion(
          nombre: _texto(s['nombre']),
          correctas: _entero(s['correctas']),
          total: _entero(s['total']),
        ),
    ],
    detalle: [
      for (final d in _lista(datos['detalle']).map(_mapa))
        DetalleRespuesta(
          preguntaId: _texto(d['preguntaId']),
          opcionElegidaId: _opcional(d['opcionElegidaId']),
          opcionCorrectaId: _texto(d['opcionCorrectaId']),
          esCorrecta: d['esCorrecta'] == true,
          solucion: _opcional(d['solucion']),
          imagenSolucion: _opcional(d['imagenSolucion']),
        ),
    ],
  );
}
