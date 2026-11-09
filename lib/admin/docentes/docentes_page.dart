import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../animacion_panel.dart';
import '../../features/teachers/domain/solicitud_docente.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'repositorio_docentes_admin.dart';

typedef AbrirEnlacePanel = Future<bool> Function(Uri enlace);

/// Abre el enlace en otra pestaña del navegador.
Future<bool> abrirEnPestana(Uri enlace) =>
    launchUrl(enlace, webOnlyWindowName: '_blank');

const _motivosSugeridos = [
  'El enlace no muestra clases tuyas.',
  'El enlace no abre o es privado.',
  'Cuéntanos más de tu experiencia.',
];

/// Solicitudes de cuenta de docente: se revisa el canal o las redes y se
/// aprueba, se rechaza con un motivo o se retira la cuenta.
class DocentesPage extends StatefulWidget {
  final RepositorioDocentesAdmin repositorio;
  final AbrirEnlacePanel abrirEnlace;
  final DateTime Function() ahora;

  const DocentesPage({
    super.key,
    required this.repositorio,
    this.abrirEnlace = abrirEnPestana,
    this.ahora = DateTime.now,
  });

  @override
  State<DocentesPage> createState() => _DocentesPageState();
}

class _DocentesPageState extends State<DocentesPage> {
  EstadoSolicitudDocente _estado = EstadoSolicitudDocente.pendiente;
  late Future<List<SolicitudDocente>> _lista = widget.repositorio.solicitudes(
    _estado,
  );
  String? _elegidoUid;
  bool _ocupado = false;

  void _cargar(EstadoSolicitudDocente estado) {
    setState(() {
      _estado = estado;
      _elegidoUid = null;
      _lista = widget.repositorio.solicitudes(estado);
    });
  }

  Future<void> _hacer(Future<void> Function() accion, String hecho) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      avisarPanel(context, hecho);
      _cargar(_estado);
    } catch (e) {
      if (mounted) avisarPanel(context, 'No se pudo: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aprobar(SolicitudDocente s) async {
    final ok = await confirmarPanel(
      context,
      titulo: 'Aprobar docente',
      mensaje:
          '${s.nombre} podrá enviar clases. Cada clase igual pasa por tu '
          'revisión antes de que la vean los alumnos.',
      confirmar: 'Aprobar',
    );
    if (ok) {
      await _hacer(() => widget.repositorio.aprobar(s), 'Docente aprobado.');
    }
  }

  Future<void> _rechazar(SolicitudDocente s, {required bool retirar}) async {
    final motivo = await pedirTexto(
      context,
      titulo: retirar ? 'Retirar cuenta de docente' : 'No aprobar',
      etiqueta: 'Motivo (lo ve el docente)',
      confirmar: retirar ? 'Retirar' : 'No aprobar',
      sugerencias: retirar ? const [] : _motivosSugeridos,
    );
    if (motivo == null) return;
    await _hacer(
      () => retirar
          ? widget.repositorio.retirar(s, motivo)
          : widget.repositorio.rechazar(s, motivo),
      retirar ? 'Cuenta retirada.' : 'Solicitud no aprobada.',
    );
  }

  Future<void> _abrir(String enlace) async {
    final uri = Uri.tryParse(enlace);
    final abierto = uri != null && await widget.abrirEnlace(uri);
    if (!abierto && mounted) avisarPanel(context, 'No se pudo abrir $enlace');
  }

  @override
  Widget build(BuildContext context) {
    return FuturoPanel<List<SolicitudDocente>>(
      futuro: _lista,
      onReintentar: () => _cargar(_estado),
      builder: (context, lista) {
        final elegido =
            lista.where((s) => s.uid == _elegidoUid).firstOrNull ??
            lista.firstOrNull;
        return PaginaPanel(
          children: [
            EncabezadoPanel(
              titulo: 'Solicitudes de docentes',
              subtitulo:
                  'Quienes piden cuenta para compartir sus clases (no necesitan '
                  'matrícula). Revisa su canal o sus redes, o escríbeles, antes '
                  'de aprobar.',
              acciones: [
                OutlinedButton.icon(
                  onPressed: () => _cargar(_estado),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (e, t) in const [
                  (EstadoSolicitudDocente.pendiente, 'Por revisar'),
                  (EstadoSolicitudDocente.aprobada, 'Aprobados'),
                  (EstadoSolicitudDocente.rechazada, 'No aprobados'),
                ])
                  ChoiceChip(
                    label: Text(e == _estado ? '$t · ${lista.length}' : t),
                    selected: _estado == e,
                    onSelected: (_) => _cargar(e),
                  ),
              ],
            ),
            if (elegido == null)
              TarjetaPanel(
                child: Text(
                  _estado == EstadoSolicitudDocente.pendiente
                      ? 'No hay solicitudes por revisar.'
                      : 'No hay nadie aquí.',
                  style: TextStyle(color: PaletaPanel.de(context).apagado),
                ),
              )
            else
              DosColumnas(
                flexPrincipal: 5,
                flexLateral: 4,
                principal: ColumnaPanel(
                  espacio: 10,
                  children: [
                    for (final (i, s) in lista.indexed)
                      FilaEntrante(
                        indice: i,
                        child: _FilaSolicitud(
                          solicitud: s,
                          elegida: s.uid == elegido.uid,
                          ahora: widget.ahora(),
                          onTap: () => setState(() => _elegidoUid = s.uid),
                        ),
                      ),
                  ],
                ),
                lateral: _detalle(elegido),
              ),
          ],
        );
      },
    );
  }

  Widget _detalle(SolicitudDocente s) {
    final p = PaletaPanel.de(context);
    return TarjetaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TituloTarjeta(
            s.nombre.isEmpty ? s.correo : s.nombre,
            extra: Insignia(
              s.estado.etiqueta,
              tono: switch (s.estado) {
                EstadoSolicitudDocente.pendiente => TonoInsignia.acento,
                EstadoSolicitudDocente.aprobada => TonoInsignia.secundario,
                EstadoSolicitudDocente.rechazada => TonoInsignia.gris,
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PaletaPanel.linea,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(s.mensaje, style: const TextStyle(height: 1.45)),
          ),
          const SizedBox(height: 12),
          FilaDato('Correo', s.correo),
          if (s.celular.isNotEmpty) FilaDato('Celular', s.celular),
          FilaDato('Enseña', s.cursos),
          FilaDato(
            'Enviada',
            '${fechaPanel(s.creadaEn)} · ${haceCuanto(s.creadaEn, widget.ahora())}',
          ),
          if (s.motivo case final motivo?) FilaDato('Motivo', motivo),
          const SizedBox(height: 14),
          Text(
            'Enlaces',
            style: TextStyle(color: p.apagado, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final e in s.enlaces)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _abrir(e),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(e, overflow: TextOverflow.ellipsis),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (s.celular.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _abrir('https://wa.me/51${s.celular}'),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Escribir por WhatsApp'),
                ),
              if (s.estado != EstadoSolicitudDocente.aprobada)
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _aprobar(s),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Aprobar'),
                ),
              if (s.estado == EstadoSolicitudDocente.pendiente)
                OutlinedButton(
                  onPressed: _ocupado
                      ? null
                      : () => _rechazar(s, retirar: false),
                  child: const Text('No aprobar'),
                ),
              if (s.estado == EstadoSolicitudDocente.aprobada)
                OutlinedButton.icon(
                  onPressed: _ocupado
                      ? null
                      : () => _rechazar(s, retirar: true),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Retirar cuenta'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'El docente ve el estado y el motivo en su perfil.',
            style: TextStyle(color: p.tenue, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilaSolicitud extends StatelessWidget {
  final SolicitudDocente solicitud;
  final bool elegida;
  final DateTime ahora;
  final VoidCallback onTap;

  const _FilaSolicitud({
    required this.solicitud,
    required this.elegida,
    required this.ahora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final s = solicitud;
    return Material(
      color: elegida ? const Color(0x12FFFFFF) : PaletaPanel.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: elegida ? p.acento.withValues(alpha: 0.6) : PaletaPanel.borde,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AvatarIniciales(s.nombre.isEmpty ? s.correo : s.nombre),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nombre.isEmpty ? s.correo : s.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      s.cursos,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.apagado, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                haceCuanto(s.creadaEn, ahora),
                style: TextStyle(color: p.tenue, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
