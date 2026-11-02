import 'package:flutter/material.dart';

import '../../core/presentation/texto.dart';
import '../../features/academic/domain/entities/version_academica.dart';
import '../../features/enrollment/domain/services/calcular_inicio_academico_service.dart';
import '../tema_panel.dart';
import '../widgets_panel.dart';
import 'modelo_estudiantes.dart';
import 'repositorio_estudiantes_admin.dart';
import 'vista_estudiante.dart';

/// Matricula a un estudiante que ya tiene cuenta. Devuelve true si se
/// matriculó.
Future<bool> mostrarMatricular(
  BuildContext context, {
  required RepositorioEstudiantesAdmin repositorio,
  required List<EstudianteAdmin> estudiantes,
  EstudianteAdmin? estudiante,
  DateTime Function() ahora = DateTime.now,
}) async {
  final hecho = await showDialog<bool>(
    context: context,
    builder: (_) => DialogoMatricular(
      repositorio: repositorio,
      estudiantes: estudiantes,
      estudiante: estudiante,
      ahora: ahora,
    ),
  );
  return hecho ?? false;
}

/// Puede recibir matrícula quien no tiene una vigente (activa, programada
/// o suspendida).
bool puedeMatricularse(EstudianteAdmin e, DateTime hoy) => switch (situacion(
  e,
  hoy,
)) {
  SituacionEstudiante.sinMatricula || SituacionEstudiante.finalizado => true,
  _ => false,
};

/// Versiones que aceptan matrículas hoy.
bool aceptaMatriculas(VersionAcademica v, DateTime hoy) {
  final abierta =
      v.estado == EstadoVersionAcademica.publicada ||
      v.estado == EstadoVersionAcademica.activa;
  final corte = v.fechaCorte;
  return abierta &&
      (corte == null ||
          !DateTime(
            corte.year,
            corte.month,
            corte.day,
          ).isBefore(DateTime(hoy.year, hoy.month, hoy.day)));
}

class DialogoMatricular extends StatefulWidget {
  final RepositorioEstudiantesAdmin repositorio;
  final List<EstudianteAdmin> estudiantes;
  final EstudianteAdmin? estudiante;
  final DateTime Function() ahora;

  const DialogoMatricular({
    super.key,
    required this.repositorio,
    required this.estudiantes,
    this.estudiante,
    this.ahora = DateTime.now,
  });

  @override
  State<DialogoMatricular> createState() => _DialogoMatricularState();
}

class _DialogoMatricularState extends State<DialogoMatricular> {
  late final DateTime _fechaMatricula = widget.ahora();
  late final Future<List<VersionAcademica>> _versiones = widget.repositorio
      .versiones()
      .then(
        (todas) =>
            todas.where((v) => aceptaMatriculas(v, _fechaMatricula)).toList(),
      );

  late EstudianteAdmin? _estudiante = widget.estudiante;
  VersionAcademica? _version;
  DateTime? _inicio;
  Future<FinTemario?>? _fin;
  bool _guardando = false;
  String? _error;

  void _elegirVersion(VersionAcademica v) {
    final inicio = const CalcularInicioAcademicoService().calcular(
      fechaMatricula: _fechaMatricula,
      fechaAperturaVersion: v.fechaApertura,
      configuracion: configuracionInicioPanel,
    );
    setState(() {
      _version = v;
      _cambiarInicio(inicio);
    });
  }

  void _cambiarInicio(DateTime inicio) {
    final version = _version!;
    _inicio = inicio;
    _fin = widget.repositorio
        .curriculo(version.id)
        .then<FinTemario?>((c) => finTemario(c, inicio))
        .catchError((Object _) => null);
  }

  Future<void> _elegirFecha() async {
    final elegida = await elegirInicio(
      context,
      inicial: _inicio!,
      desde: _fechaMatricula,
    );
    if (elegida != null && mounted) setState(() => _cambiarInicio(elegida));
  }

  Future<void> _matricular() async {
    final estudiante = _estudiante;
    final version = _version;
    final inicio = _inicio;
    if (estudiante == null || version == null || inicio == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repositorio.matricular(
        estudiante: estudiante,
        version: version,
        fechaMatricula: _fechaMatricula,
        inicio: inicio,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'No se pudo matricular: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaPanel.de(context);
    final listo = _estudiante != null && _version != null && _inicio != null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ColumnaPanel(
            espacio: 18,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Matricular estudiante',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              _seccion(
                'Cuenta del estudiante (ya registrada en la app)',
                _estudiante == null ? _buscador() : _elegido(_estudiante!),
              ),
              _seccion(
                'Versión académica',
                FutureBuilder<List<VersionAcademica>>(
                  future: _versiones,
                  builder: (context, s) {
                    if (s.hasError) {
                      return Text(
                        'No se pudieron leer las versiones.',
                        style: TextStyle(color: p.alerta),
                      );
                    }
                    final versiones = s.data;
                    if (versiones == null) {
                      return const LinearProgressIndicator();
                    }
                    if (versiones.isEmpty) {
                      return Text(
                        'No hay versiones abiertas a matrículas.',
                        style: TextStyle(color: p.apagado),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final v in versiones)
                          ChoiceChip(
                            label: Text(v.nombre),
                            selected: _version?.id == v.id,
                            onSelected: (_) => _elegirVersion(v),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (_inicio case final inicio?) ...[
                RejillaPanel(
                  anchoMinimo: 220,
                  children: [
                    _seccion(
                      'Fecha de matrícula',
                      Text(
                        fechaPanel(_fechaMatricula),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _seccion(
                      'Inicio académico (día 1)',
                      OutlinedButton.icon(
                        onPressed: _elegirFecha,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(fechaPanel(inicio)),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Los domingos no cuentan como día académico. Si se matricula '
                  'después de las ${configuracionInicioPanel.horaCorte}:00, '
                  'empieza al día siguiente.',
                  style: TextStyle(color: p.tenue, fontSize: 12),
                ),
                FutureBuilder<FinTemario?>(
                  future: _fin,
                  builder: (context, s) {
                    final fin = s.data;
                    if (fin == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.secundario.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: p.secundario.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'Terminará el temario (${fin.dias} días académicos, '
                        '${fin.temas} temas) aproximadamente el '
                        '${fechaPanel(fin.fecha)}.',
                        style: const TextStyle(height: 1.5),
                      ),
                    );
                  },
                ),
              ],
              if (_error case final e?)
                Text(e, style: TextStyle(color: p.alerta)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: listo && !_guardando ? _matricular : null,
                    icon: _guardando
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Matricular'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccion(String etiqueta, Widget contenido) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            color: PaletaPanel.de(context).apagado,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        contenido,
      ],
    );
  }

  Widget _elegido(EstudianteAdmin e) {
    final p = PaletaPanel.de(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaletaPanel.bordeFuerte),
      ),
      child: Row(
        children: [
          AvatarIniciales(e.nombre),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [e.correo, ?e.carrera].join(' · '),
                  style: TextStyle(color: p.apagado, fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.estudiante == null)
            TextButton(
              onPressed: () => setState(() => _estudiante = null),
              child: const Text('Cambiar'),
            ),
        ],
      ),
    );
  }

  Widget _buscador() {
    final hoy = _fechaMatricula;
    final candidatos = widget.estudiantes
        .where((e) => puedeMatricularse(e, hoy))
        .toList();
    if (candidatos.isEmpty) {
      return Text(
        'Todos los estudiantes registrados ya tienen matrícula. El '
        'estudiante debe crear su cuenta en la app primero.',
        style: TextStyle(color: PaletaPanel.de(context).apagado),
      );
    }
    return Autocomplete<EstudianteAdmin>(
      displayStringForOption: (e) => e.nombre,
      optionsBuilder: (valor) {
        final texto = normalizarTexto(valor.text.trim());
        return candidatos.where(
          (e) => normalizarTexto('${e.nombre} ${e.correo}').contains(texto),
        );
      },
      onSelected: (e) => setState(() => _estudiante = e),
      fieldViewBuilder: (context, controlador, foco, alEnviar) => TextField(
        controller: controlador,
        focusNode: foco,
        onSubmitted: (_) => alEnviar(),
        decoration: const InputDecoration(
          hintText: 'Buscar por nombre o correo',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }
}
