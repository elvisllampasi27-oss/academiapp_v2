import 'usuario_academiapp.dart';

enum TipoEstadoSesionEstudiante { cargando, noAutenticado, autenticado }

class EstadoSesionEstudiante {
  final TipoEstadoSesionEstudiante tipo;
  final UsuarioAcademiApp? usuario;

  const EstadoSesionEstudiante._({required this.tipo, this.usuario});

  const EstadoSesionEstudiante.cargando()
    : this._(tipo: TipoEstadoSesionEstudiante.cargando);

  const EstadoSesionEstudiante.noAutenticado()
    : this._(tipo: TipoEstadoSesionEstudiante.noAutenticado);

  const EstadoSesionEstudiante.autenticado(UsuarioAcademiApp usuario)
    : this._(tipo: TipoEstadoSesionEstudiante.autenticado, usuario: usuario);
}
