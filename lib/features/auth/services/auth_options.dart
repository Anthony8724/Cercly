import 'package:flutter/foundation.dart';

enum MetodoAcceso { google, microsoft, facebook, celular }

class AuthOptions {
  const AuthOptions({
    this.google = const bool.fromEnvironment('AUTH_GOOGLE_ENABLED'),
    this.microsoft = const bool.fromEnvironment('AUTH_MICROSOFT_ENABLED'),
    this.facebook = const bool.fromEnvironment('AUTH_FACEBOOK_ENABLED'),
    this.celular = const bool.fromEnvironment('AUTH_PHONE_ENABLED'),
  });
  final bool google, microsoft, facebook, celular;
  bool disponible(MetodoAcceso metodo) => switch (metodo) {
    MetodoAcceso.google => google,
    MetodoAcceso.microsoft => microsoft,
    MetodoAcceso.facebook => facebook,
    MetodoAcceso.celular => celular,
  };
  static String redirect({bool web = kIsWeb, Uri? base}) => web
      ? (base ?? Uri.base).toString().split(RegExp(r'[?#]')).first
      : 'com.cercly.cercly://auth-callback/';
}

String? validarTelefono(String? value) =>
    RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Usa formato internacional: +593991234567 (8 a 15 dígitos).';

String? validarCorreo(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Ingresa un correo electrónico válido';
