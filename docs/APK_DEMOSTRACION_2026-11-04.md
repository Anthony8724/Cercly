# APK de demostración y verificación del código

Se reutiliza la APK validada en el Honor, sin nueva instalación ni nueva versión:

- Archivo local: `artifacts/Cercly-v0.1.5-code7-staging-geofencing-diagnostics.apk`.
- Paquete: `com.cercly.cercly.staging`.
- Versión: `0.1.5`, versionCode **7**.
- Tamaño: **62 522 606 bytes** (aproximadamente 59.63 MiB).
- SHA-256: `aad9615871826033b65f69891e106d9810f9c90087cda8cd9e5f63663020e529`.
- SHA-256 del certificado: `f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5`.

El 3 de noviembre se ejecutó una compilación de comprobación del código integrado, con los mismos parámetros Staging y firma privada existente. **La APK resultante tuvo exactamente el mismo SHA-256 que la validada**: no solo coincide la versión, coincide todo el archivo. Se conserva el original y no se distribuye una candidata diferente. La APK y las claves locales están excluidas de Git; no se creó una release pública.

Reproducción en el equipo configurado:

```sh
flutter analyze
flutter test
flutter test --dart-define=CERCLY_STAGING=true test/geofencing_experimental_service_test.dart test/staging_proximity_diagnostics_test.dart
flutter build apk --release --dart-define-from-file=config/supabase.staging.local.json --dart-define=CERCLY_STAGING=true
git diff --check
```

El JSON local debe contener exclusivamente el host Staging y clave publicable; no se incluye en Git. La firma se obtiene de `android/key.properties` privado. No copiar secretos al comando ni activar las banderas `CERCLY_UI_EVALUATION`/`CERCLY_DEMO_RELEASE`, que corresponden a otra variante.

Código de aplicación consolidado en el commit `b36242c` (`feat(android): consolidate consent and validated staging geofencing`). Los commits posteriores de esta entrega contienen preparación local/documentación y no cambian los archivos que producen esta APK.

## Resultados del 3 de noviembre

| Comprobación | Resultado |
|---|---|
| Flutter analyze | Sin issues |
| Flutter test completo | 257 aprobadas, 9 omitidas; las integraciones sin entorno remoto configurado no se cuentan como ejecutadas |
| Pruebas focales con Staging habilitado | 15 aprobadas |
| Compilación Android Release Staging/Kotlin | Correcta; mismo binario validado |
| Firma | apksigner correcto, certificado compatible con el instalado |
| Configuración APK | Único host Supabase encontrado: `dlajxviqhkdcqnmczhvr.supabase.co` |
| Manifiesto compilado | Permisos foreground/background/notificaciones; receivers de geofence, boot y QA no exportados |
| Aislamiento | Manifiesto normal sin receivers QA ni permiso background; no se generó APK Production |
| Android unit tests independientes | No hay suite `android/app/src/test` configurada; no se presenta como ejecutada. Se dispone de compilación, pruebas Flutter del puente y ensayo real en Honor |
| Ensayo físico del teléfono con ubicación de desarrollo | ENTER, pantalla previamente apagada, publicación nueva y navegación confirmados; ver informe Honor |

No se modificó código de aplicación para preparar esta entrega: se consolidó el avance existente y se añadieron documentación y exclusiones de evidencia privada. Los archivos locales de configuración/fixtures de Supabase se versionan como preparación histórica, no como un despliegue: no se ejecutaron migraciones ni scripts remotos. El fixture publicado usa una cuenta de ejemplo que debe sustituirse únicamente bajo autorización administrativa; no debe ejecutarse para la demostración.

Para mañana, mantener instalada la code7 y seguir [el procedimiento](DEMO_ACADEMICA_2026-11-04.md). La demostración depende de permisos, consentimiento, Play Services, red y promoción vigente. GO técnico Staging; sin autorización de publicación pública/Production.

## Automatización de develop

El workflow de GitHub ejecuta análisis, pruebas generales y focales, y compila **debug STAGING** con `vars.CERCLY_STAGING_PUBLISHABLE_KEY`. No usa el endpoint Production ni publica releases. El artefacto `Cercly-STAGING-CI-debug` lleva firma debug: **no reemplazar con él la Release code7 del Honor**. La clave de firma Release permanece exclusivamente local.
