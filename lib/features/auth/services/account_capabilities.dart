import '../../usuarios/models/usuario_model.dart';

enum AccountMode { usuario, propietario, administracion }

class AccountCapabilities {
  const AccountCapabilities({
    required this.role,
    required this.owner,
    required this.admin,
    required this.superadmin,
  });

  final String role;
  final bool owner;
  final bool admin;
  final bool superadmin;

  factory AccountCapabilities.fromRole(String role) {
    if (!UsuarioModel.rolesPermitidos.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    return AccountCapabilities(
      role: role,
      owner: role == UsuarioModel.rolPropietario,
      admin: role == UsuarioModel.rolAdministrador,
      superadmin: false,
    );
  }

  factory AccountCapabilities.fromServer(Map<String, dynamic> row) {
    final role = row['rol'];
    final owner = row['propietario'];
    final admin = row['administrador'];
    final superadmin = row['superadministrador'];
    if (role is! String ||
        !UsuarioModel.rolesPermitidos.contains(role) ||
        owner is! bool ||
        admin is! bool ||
        superadmin is! bool ||
        admin != (role == UsuarioModel.rolAdministrador) ||
        (superadmin && !admin)) {
      throw const FormatException('Capacidades inconsistentes');
    }
    return AccountCapabilities(
      role: role,
      owner: owner,
      admin: admin,
      superadmin: superadmin,
    );
  }

  List<AccountMode> get availableModes => [
    AccountMode.usuario,
    if (owner) AccountMode.propietario,
    if (admin) AccountMode.administracion,
  ];

  bool allows(AccountMode mode) => availableModes.contains(mode);

  AccountMode get defaultMode => admin
      ? AccountMode.administracion
      : owner
      ? AccountMode.propietario
      : AccountMode.usuario;
}
