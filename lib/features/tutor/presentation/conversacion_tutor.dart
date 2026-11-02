import 'package:flutter/foundation.dart';

import '../domain/entities/mensaje_tutor.dart';
import '../domain/exceptions/error_tutor.dart';
import '../domain/repositories/servicio_tutor.dart';

/// Estado del chat de dudas de un tema. Vive mientras la pantalla del tema
/// está abierta: cerrar y volver a abrir el chat conserva la conversación.
class ConversacionTutor extends ChangeNotifier {
  /// Turnos previos que se envían como contexto (cuida el costo).
  static const maximoHistorial = 6;

  final ServicioTutor servicio;
  final String versionId;
  final String temaId;

  ConversacionTutor({
    required this.servicio,
    required this.versionId,
    required this.temaId,
  });

  final List<MensajeTutor> _mensajes = [];
  bool _pensando = false;
  bool _descartada = false;
  String? _error;
  int? _restantesHoy;
  int? _limiteDiario;

  List<MensajeTutor> get mensajes => List.unmodifiable(_mensajes);
  bool get pensando => _pensando;
  String? get error => _error;
  int? get restantesHoy => _restantesHoy;
  int? get limiteDiario => _limiteDiario;

  Future<void> preguntar(String texto) async {
    final pregunta = texto.trim();
    if (pregunta.isEmpty || _pensando) return;

    final inicio = _mensajes.length > maximoHistorial
        ? _mensajes.length - maximoHistorial
        : 0;
    final historial = _mensajes.sublist(inicio);

    _mensajes.add(MensajeTutor.estudiante(pregunta));
    _pensando = true;
    _error = null;
    notifyListeners();

    try {
      final respuesta = await servicio.preguntar(
        versionId: versionId,
        temaId: temaId,
        pregunta: pregunta,
        historial: historial,
      );
      _mensajes.add(MensajeTutor.tutor(respuesta.texto));
      _restantesHoy = respuesta.restantesHoy;
      _limiteDiario = respuesta.limiteDiario;
    } on ErrorTutor catch (e) {
      _error = e.mensaje;
    } catch (_) {
      _error = 'El tutor no pudo responder. Inténtalo de nuevo.';
    } finally {
      _pensando = false;
      if (!_descartada) notifyListeners();
    }
  }

  @override
  void dispose() {
    _descartada = true;
    super.dispose();
  }
}
