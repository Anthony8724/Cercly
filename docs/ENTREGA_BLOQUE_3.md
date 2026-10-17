# Entrega del bloque 3

Implementación en `develop`, sin push, cambios de credenciales ni migraciones remotas. El archivo ajeno `README.md.respaldo` no se incluye.

## Resultado de validación

| Comprobación | Resultado |
| --- | --- |
| `flutter pub get` | Aprobado; Supabase Flutter se conserva en 2.17.2 |
| Formato | Solo archivos modificados; chequeo previo detectó formato ajeno |
| `flutter analyze` | Sin incidencias |
| `flutter test` | 118 aprobadas, 8 omitidas por configuración de integración remota; 0 fallidas al cierre |
| Pruebas Auth/navegación en Chrome | 28 aprobadas |
| Pruebas específicas tras el último ajuste | 9 aprobadas |
| `git diff --check` | Sin errores |
| APK debug con configuración local | Generado en `build/app/outputs/flutter-apk/app-debug.apk` |
| Build Web con configuración local | Generado en `build/web` |
| Pruebas SQL de roles/perfiles | 11 aserciones preparadas, no ejecutadas; falta entorno PostgreSQL/Supabase local |
| Login externo / entrega SMS real | No ejecutados; proveedores deshabilitados en settings |

Durante el desarrollo se corrigieron fallos de configuración del transporte simulado, composición de URL, desbordamiento del separador a 320 px, reintento OAuth y desplazamiento de la prueba de registro. Ninguno queda abierto en las pruebas Flutter. El build Web emitió un aviso sobre la codificación preexistente de `.gitignore`, pero completó; no se modificó ese archivo. Gradle emitió un aviso de acceso nativo de Java, sin impedir el APK.

Correo está habilitado en el proyecto consultado, pero no se certificó un inicio de sesión real. Google, Microsoft/Azure, Facebook y teléfono están deshabilitados. La UI los muestra como no disponibles. Ver [configuración, auditoría y pasos pendientes](AUTENTICACION_BLOQUE_3.md).

La auditoría SQL se basa en las migraciones del repositorio; no se verificó divergencia de esquema/RLS en la base remota. Es necesario validar la migración y los RPC de aprobación/reclamación en un entorno local o staging antes de desplegarla. No se modificaron roles existentes de manera masiva.

## Commits preparados

Se entrega una serie de seis parches ordenados, junto con el diff completo, en `/tmp/cercly-bloque-3/`. Los parches representan los commits propuestos; **no se crearon commits ni se modificó el índice Git**. Aplicarlos solo sobre una copia limpia del commit base indicado en el README de la serie: este árbol de trabajo ya contiene su resultado y no debe recibirlos otra vez.

1. `fix(auth): autorizar navegación exclusivamente con roles de base de datos`
2. `refactor(auth): centralizar acceso y configuración de proveedores`
3. `feat(auth): renovar formularios y recuperación de contraseña`
4. `feat(auth): integrar OAuth y retorno seguro de sesión`
5. `feat(auth): agregar acceso telefónico por OTP`
6. `docs(auth): documentar validación y configuración externa`

## Archivos creados o modificados

- `android/app/src/main/AndroidManifest.xml`
- `docs/AUTENTICACION_BLOQUE_3.md`
- `docs/ENTREGA_BLOQUE_3.md`
- `lib/features/auth/screens/auth_gate.dart`
- `lib/features/auth/screens/auth_recovery_host.dart`
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/mi_cuenta_screen.dart`
- `lib/features/auth/screens/password_screen.dart`
- `lib/features/auth/screens/phone_auth_screen.dart`
- `lib/features/auth/screens/register_screen.dart`
- `lib/features/auth/services/auth_options.dart`
- `lib/features/auth/services/auth_service.dart`
- `lib/main.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `scripts/check_auth_settings.py`
- `supabase/config.toml`
- `supabase/migrations/20261017233138_fortalecer_acceso_perfiles.sql`
- `supabase/tests/auth_access_test.sql`
- `test/auth_oauth_test.dart`
- `test/auth_password_test.dart`
- `test/auth_phone_test.dart`
- `test/auth_roles_test.dart`
- `test/auth_service_test.dart`
- `test/auth_ui_test.dart`
- `test/widget_test.dart`
