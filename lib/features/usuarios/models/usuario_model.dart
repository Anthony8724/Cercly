class UsuarioModel {
  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.rol,
    this.creadoEn,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('El identificador es obligatorio.');
    }

    if (nombre.trim().length < 2 || nombre.trim().length > 80) {
      throw ArgumentError('El nombre debe tener entre 2 y 80 caracteres.');
    }

    if (!rolesPermitidos.contains(rol)) {
      throw ArgumentError('El rol del usuario no es válido.');
    }
  }

  static const String rolUsuario = 'usuario';
  static const String rolPropietario = 'propietario';
  static const String rolAdministrador = 'administrador';

  static const Set<String> rolesPermitidos = {
    rolUsuario,
    rolPropietario,
    rolAdministrador,
  };

  final String id;
  final String nombre;
  final String rol;
  final DateTime? creadoEn;

  bool get esPropietario => rol == rolPropietario;
  bool get esAdministrador => rol == rolAdministrador;

  Map<String, dynamic> toSupabaseParaActualizar() {
    return {'nombre': nombre.trim()};
  }

  factory UsuarioModel.fromSupabase(Map<String, dynamic> datos) {
    return UsuarioModel(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      rol: datos['rol'] as String? ?? rolUsuario,
      creadoEn: datos['creado_en'] == null
          ? null
          : DateTime.parse(datos['creado_en'] as String).toLocal(),
    );
  }
}
