import 'package:flutter/material.dart';

import '../../features/academic/domain/entities/version_academica.dart';
import '../estudiantes/modelo_estudiantes.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'modelo_versiones.dart';
import 'repositorio_versiones_admin.dart';

/// Crea un ciclo nuevo copiando el temario de otro. Queda en
/// "Preparación": nadie se matricula hasta que lo publiques.
class NuevaVersionPage extends StatefulWidget {
  final RepositorioVersionesAdmin repositorio;
  final List<VersionAcademica> versiones;
  final VoidCallback onCancelar;
  final ValueChanged<String> onCreada;
  final DateTime Function() ahora;

  const NuevaVersionPage({
    super.key,
    required this.repositorio,
    required this.versiones,
    required this.onCancelar,
    required this.onCreada,
    this.ahora = DateTime.now,
  });

  @override
  State<NuevaVersionPage> createState() => _NuevaVersionPageState();
}

class _NuevaVersionPageState extends State<NuevaVersionPage> {
  final _nombre = TextEditingController();
  late DateTime _apertura = widget.ahora().add(const Duration(days: 30));
  DateTime? _corte;
  late String _origen = widget.versiones.first.id;
  bool _copiarMaterial = true;
  bool _creando = false;
  String? _progreso;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  String get _id => idDesdeNombre(_nombre.text);

  Future<void> _crear() async {
    final nombre = _nombre.text.trim();
    if (nombre.length < 3 || _id.isEmpty) {
      setState(
        () => _error = 'Escribe el nombre del ciclo (p. ej. Ciclo 2027-I).',
      );
      return;
    }
    if (widget.versiones.any((v) => v.id == _id)) {
      setState(() => _error = 'Ya existe una versión con el código $_id.');
      return;
    }
    if (_corte != null && _corte!.isBefore(_apertura)) {
      setState(
        () => _error = 'El cierre de matrículas va después de la apertura.',
      );
      return;
    }
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      await widget.repositorio.crear(
        VersionAcademica(
          id: _id,
          codigo: _id,
          nombre: nombre,
          fechaApertura: _apertura,
          fechaCorte: _corte,
          estado: EstadoVersionAcademica.preparacion,
        ),
        origenId: _origen,
        copiarMaterial: _copiarMaterial,
        progreso: (m) {
          if (mounted) setState(() => _progreso = m);
        },
      );
      if (mounted) widget.onCreada(_id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creando = false;
          _error = e is StateError ? e.message : 'No se pudo crear: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    return PaginaPanel(
      children: [
        EncabezadoPanel(
          migas: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _creando ? null : widget.onCancelar,
                child: Text(
                  'Versiones y matrículas',
                  style: TextStyle(color: p.apagado),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: p.tenue),
              const Text('Nueva versión'),
            ],
          ),
          titulo: 'Nueva versión',
          subtitulo:
              'Se crea en "Preparación". Cuando esté lista, cámbiala a '
              '"Publicada" para aceptar matrículas.',
        ),
        DosColumnas(
          flexPrincipal: 1,
          principal: ColumnaPanel(
            children: [
              TarjetaPanel(
                child: ColumnaPanel(
                  espacio: 14,
                  children: [
                    const TituloTarjeta('Datos y fechas'),
                    TextField(
                      controller: _nombre,
                      enabled: !_creando,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ciclo 2027-I',
                        helperText: _id.isEmpty ? null : 'Código: $_id',
                      ),
                    ),
                    _fecha('Apertura (primer día posible)', _apertura, (f) {
                      setState(() => _apertura = f);
                    }),
                    _fecha(
                      'Matrículas hasta (opcional)',
                      _corte,
                      (f) => setState(() => _corte = f),
                      quitar: () => setState(() => _corte = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
          lateral: TarjetaPanel(
            child: ColumnaPanel(
              espacio: 14,
              children: [
                const TituloTarjeta('¿De dónde sale el temario?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in widget.versiones)
                      ChoiceChip(
                        label: Text('Copiar de ${v.nombre}'),
                        selected: _origen == v.id,
                        onSelected: _creando
                            ? null
                            : (_) => setState(() => _origen = v.id),
                      ),
                  ],
                ),
                Text(
                  'Se copian las áreas, cursos y temas en el mismo orden. Luego '
                  'puedes ajustarlos en Cursos y temas.',
                  style: TextStyle(color: p.apagado),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _copiarMaterial,
                  onChanged: _creando
                      ? null
                      : (v) => setState(() => _copiarMaterial = v ?? false),
                  title: const Text(
                    'Copiar también videos, separatas y quizzes',
                  ),
                  subtitle: Text(
                    'Se pueden reemplazar después. Puede tardar un minuto.',
                    style: TextStyle(color: p.tenue, fontSize: 12),
                  ),
                ),
                if (_progreso case final m? when _creando)
                  Row(
                    children: [
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m)),
                    ],
                  ),
                if (_error case final e?)
                  Text(e, style: TextStyle(color: p.alerta)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _creando ? null : widget.onCancelar,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _creando ? null : _crear,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Crear versión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fecha(
    String etiqueta,
    DateTime? valor,
    ValueChanged<DateTime> elegir, {
    VoidCallback? quitar,
  }) {
    final p = PaletaPanel.de(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: TextStyle(color: p.apagado, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                valor == null ? 'Sin fecha' : fechaPanel(valor),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (valor != null && quitar != null)
          TextButton(
            onPressed: _creando ? null : quitar,
            child: const Text('Quitar'),
          ),
        OutlinedButton(
          onPressed: _creando
              ? null
              : () async {
                  final hoy = widget.ahora();
                  final f = await showDatePicker(
                    context: context,
                    initialDate: valor ?? _apertura,
                    firstDate: DateTime(hoy.year - 1),
                    lastDate: DateTime(hoy.year + 3),
                  );
                  if (f != null) elegir(f);
                },
          child: const Text('Elegir'),
        ),
      ],
    );
  }
}

/// Editar nombre y fechas de una versión.
class DialogoDatosVersion extends StatefulWidget {
  final VersionAcademica version;

  const DialogoDatosVersion({super.key, required this.version});

  @override
  State<DialogoDatosVersion> createState() => _DialogoDatosVersionState();
}

class _DialogoDatosVersionState extends State<DialogoDatosVersion> {
  late final _nombre = TextEditingController(text: widget.version.nombre);
  late DateTime _apertura = widget.version.fechaApertura;
  late DateTime? _corte = widget.version.fechaCorte;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegir(bool apertura) async {
    final f = await showDatePicker(
      context: context,
      initialDate: apertura ? _apertura : (_corte ?? _apertura),
      firstDate: DateTime(_apertura.year - 1),
      lastDate: DateTime(_apertura.year + 3),
    );
    if (f == null) return;
    setState(() {
      if (apertura) {
        _apertura = f;
      } else {
        _corte = f;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.version;
    final valido =
        _nombre.text.trim().length >= 3 &&
        (_corte == null || !_corte!.isBefore(_apertura));
    return AlertDialog(
      title: Text('Editar ${v.nombre}'),
      content: SizedBox(
        width: 440,
        child: ColumnaPanel(
          espacio: 12,
          children: [
            TextField(
              controller: _nombre,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apertura'),
              subtitle: Text(fechaPanel(_apertura)),
              trailing: OutlinedButton(
                onPressed: () => _elegir(true),
                child: const Text('Cambiar'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Matrículas hasta'),
              subtitle: Text(
                _corte == null ? 'Sin fecha' : fechaPanel(_corte!),
              ),
              trailing: Wrap(
                spacing: 6,
                children: [
                  if (_corte != null)
                    TextButton(
                      onPressed: () => setState(() => _corte = null),
                      child: const Text('Quitar'),
                    ),
                  OutlinedButton(
                    onPressed: () => _elegir(false),
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: !valido
              ? null
              : () => Navigator.pop(
                  context,
                  VersionAcademica(
                    id: v.id,
                    codigo: v.codigo,
                    nombre: _nombre.text.trim(),
                    fechaApertura: _apertura,
                    fechaCorte: _corte,
                    estado: v.estado,
                  ),
                ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
