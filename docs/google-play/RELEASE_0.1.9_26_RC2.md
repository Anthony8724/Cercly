# Release 0.1.9+26 RC2 — CANDIDATA NO APROBADA

Código compilado: `40c1f2fd5af3027ccd896e03ef1a17e848068069`. Base develop 3ef19a820263c2add7db27a78d43570dd5f52cfd; PR #41 permanece en borrador. La documentación posterior no cambia el binario. VersionCode 26 **pendiente de comprobar en Console**; si ya se utilizó, elegir max+1 y recompilar ambos artefactos.

## Comportamiento y configuración

Cómo llegar confirma apertura de Google Maps con api=1 y destination; no consulta GPS ni invoca calcular-ruta. UI/servicio Supabase y adaptador legado impiden enviar al proveedor real. Las rutas internas se conservan en código, deshabilitadas sin flag de reactivación. No se despliega backend ni se modifica una versión distribuida anterior.

Supabase Production: https://aimubazregckmjchnszf.supabase.co, clave publicable local existente; ningún secreto de servidor. Firebase no sustituye a Supabase. RIIOTE continúa en Mi cuenta. Radar por defecto apagado, avisos/push false y geofencing/push promocional Production bloqueados; no se reinicia silenciosamente un consentimiento previo legítimo.

## Compilación reproducible

Flutter 3.47.5 / Dart 3.13.4 y lockfiles conservados. Sin actualización Flutter/dependencias Android. Configuración local de firma existente, no regenerada ni subida. Defines privados locales contienen solo URL/clave publicable Production; no flags de evaluación, Staging, proximidad ni simulaciones.

```sh
flutter pub get
flutter analyze
flutter test --no-pub
flutter build apk --release --no-pub --dart-define-from-file=/ruta/privada/production-defines.json
flutter build appbundle --release --no-pub --dart-define-from-file=/ruta/privada/production-defines.json
```

Gradle rechazó en tres comprobaciones reales los secretos ORS/service_role y rutas simuladas públicas. Los valores de esas pruebas son sintéticos y no se usan para generar RC2.

## Artefactos nuevos

Directorio de entrega creado y verificado: `/home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-RC2-CANDIDATA-20261119/`.

| Archivo | Bytes | SHA-256 |
|---|---:|---|
| Cercly-Produccion-0.1.9+26-RC2.apk | 63679643 | `812e72ead744d8144e029154be5cabe990c9c030e74d3805fef82a86c5b22f49` |
| Cercly-Produccion-0.1.9+26-RC2.aab | 61465363 | `36fb9c545aebda8e0ea254766b8b36407229b46b2054a9660eafd151234079f5` |

Son hashes distintos de c14e42d. Las carpetas +25 y +26 anterior se conservan sin sobrescribir. No distribuir como versión aprobada.

## Comprobaciones

APK y AAB: com.cercly.cercly, versionName 0.1.9, code 26, min 24, compile/target 36. Firma local Cercly Upload RSA 4096, SHA-256 f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5, igual a la histórica. Pendiente compararla con Upload key certificate de Play; no confundir con firma de distribución Play App Signing.

bundletool validate aprobado; zipalign -P16 y ELF64 con alineación >=16 KB aprobados. ABIs arm64-v8a, armeabi-v7a y x86_64. No equivale a ejecución nativa en un equipo de 16 KB.

Escaneo de todas las entradas descomprimidas para PEM privado, sb_secret, service_role JWT, service account, keystore/.env/key.properties y contraseñas conocidas: sin hallazgos. Se encontraron Production y riiote.org, no Staging ni cadenas de api.heigit.org/api.openrouteservice.org dentro del alcance definido. La ausencia de cadenas no sustituye una prueba de tráfico, pero coincide con guardas y pruebas de cero invocaciones.

Permisos: Internet, coarse/fine location, notificaciones, vibración, wake lock, estado de red, recepción FCM y permiso propio de receptores; sin background location, SMS, contactos ni micrófono. Receivers de proximidad siguen deshabilitados/no exportados; receivers FCM exportados protegidos por permiso de sistema, servicios/providers internos no exportados y backup false.

Pruebas y límites: [PRUEBAS_Y_RIESGOS.md](PRUEBAS_Y_RIESGOS.md). Falta dispositivo HONOR, prueba Auth/Storage HTTP integral, publicación aprobada de política, decisiones del titular y contraste Console. La migración de eliminación se incluye como código preparado, **no está desplegada por instalar el APK**.

CI comprobado: [44639065759](https://github.com/Anthony8724/Cercly/actions/runs/44639065759), success, HEAD 48257b854ea14ef20b1dcf0afeb65fd1a3f8249b. Incluye análisis/pruebas y APK debug Staging; no genera estos artefactos release Production. Las diferencias con el código compilado 40c1f2f son documentales. Evidencia saneada en evidencias/ci-rc2.json.
