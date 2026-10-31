enum AutorMensaje { estudiante, tutor }

class MensajeTutor {
  final AutorMensaje autor;
  final String texto;

  const MensajeTutor(this.autor, this.texto);

  const MensajeTutor.estudiante(this.texto) : autor = AutorMensaje.estudiante;

  const MensajeTutor.tutor(this.texto) : autor = AutorMensaje.tutor;
}
