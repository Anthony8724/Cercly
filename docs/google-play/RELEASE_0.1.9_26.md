# Release candidata Cercly 0.1.9+26

Fecha: 19/11/2026. **CANDIDATA NO APROBADA PARA PUBLICACIÓN.** VersionCode 26 pendiente de contrastar con Play Console. No sobrescribe +25.

## Fuente y configuración

- Base develop: 3ef19a820263c2add7db27a78d43570dd5f52cfd, PR #40 fusionado preservando historial.
- Código compilado: c14e42d6441b09779e76d7f99404bc7dd1100f74, rama release/play-store-0.1.9-26.
- La documentación posterior no cambia el código de esos binarios. Si se modifica código/flags, reconstruir y actualizar hashes.
- Flutter 3.47.5 / Dart 3.13.4, Java de entorno local, AGP 9.1.0; Gradle 9.3.1; NDK 28.2.13676358. Lockfiles conservados.
- applicationId com.cercly.cercly; versionName 0.1.9; versionCode 26; minSdk 24; compileSdk/targetSdk 36, comprobados en APK y manifiesto AAB.
- URL configurada exclusivamente https://aimubazregckmjchnszf.supabase.co y clave publicable existente. El archivo de defines queda fuera de Git. Sin ORS_API_KEY, service_role, credenciales de usuario ni flags staging/evaluation/demo/rutas simuladas/proximidad.
- El servicio real llama calcular-ruta en Supabase y este mantiene api.heigit.org/openrouteservice. No se desplegó ni migró backend.

## Compilación y verificación

```sh
flutter pub get
flutter analyze
flutter test --no-pub
# Defines privados locales con SOLO URL y clave publicable Production.
flutter build apk --release --no-pub --dart-define-from-file=/ruta/privada/production-defines.json
flutter build appbundle --release --no-pub --dart-define-from-file=/ruta/privada/production-defines.json
deno test --node-modules-dir=none --frozen --allow-env=SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,SUPABASE_ANON_KEY,SUPABASE_PUBLISHABLE_KEYS,ORS_API_KEY supabase/functions/calcular-ruta
deno check --node-modules-dir=none --frozen supabase/functions/calcular-ruta/index.ts
```

Los valores reales de firma y claves no deben copiarse a este documento. android/key.properties referencia la clave de carga ya autorizada; no se generó otra.

## Inventario

Directorio final: `/home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-CANDIDATA-20261119/`.

| Artefacto | Bytes | MiB | SHA-256 |
|---|---:|---:|---|
| Cercly-Produccion-0.1.9+26.apk | 63810803 | 60.85 | `1aff357f2ab010f56d071a9af73a450ce355f5ba3006b6391ffa32550361d9a5` |
| Cercly-Produccion-0.1.9+26.aab | 61666593 | 58.81 | `bb209970cc1d0e125230f9a2df3cb7201200dd9791886d6d006e75362c6d31ec` |

Recursos: icono-play-512.png y grafico-promocional-1024x500.png. Evidencias: firmas, manifiestos, bundle config/validación, zipalign, escaneo, análisis/pruebas, hashes e inventario. Los binarios y PNG generados no se incluyen en Git. Fuentes SVG revisables en recursos/.

## Firma

APK: apksigner verify aprobado, esquema v2, un firmante RSA 4096. AAB: jarsigner `jar verified`; certificado CN=Cercly Upload, OU=Android, O=Cercly, C=EC, válido hasta 14/03/2054.

SHA-256 certificado: `f0498657b1f4c7b74c9f889f44b72a5760988fbd640a94d1d9a1e2f1c48566d5`.
SHA-1 certificado: `eed0f47e461b6ea0e78be87f60c12ed7818efdbf`.

Coincide con la firma histórica local y con el artefacto +25 al contrastarlo. **Pendiente** compararlo con el certificado de carga de Play Console. Play App Signing puede usar un certificado de distribución distinto. No se alteró ni subió material privado.

## Artefacto y permisos

ABIs: armeabi-v7a, arm64-v8a y x86_64. Ocho bibliotecas ELF64 por artefacto con segmentos LOAD de al menos 16.384 bytes. APK zipalign -P 16 aprobado. AAB PAGE_ALIGNMENT_16K y bundletool validate aprobado. No hay instalación ejecutada en dispositivo de 16 KB; el AVD local es una imagen preview y falla antes de estar disponible.

Permisos finales: INTERNET, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION, POST_NOTIFICATIONS, VIBRATE, WAKE_LOCK, ACCESS_NETWORK_STATE, com.google.android.c2dm.permission.RECEIVE y permiso propio DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION. No background location, SMS, contactos, micrófono ni lectura amplia de almacenamiento.

Exportados: MainActivity para launcher/OAuth; dos receptores FCM protegidos por com.google.android.c2dm.permission.SEND y ProfileInstallReceiver protegido por android.permission.DUMP. Providers/servicios internos no exportados; receptores de proximidad deshabilitados y no exportados. allowBackup=false; sin permiso de Internet en texto claro habilitado en el manifiesto inspeccionado. Verificar además componentes y enlaces en ejecución.

## Pruebas y límites

Flutter suite: 461 aprobadas/21 omitidas/0 fallidas; adicionalmente 9 integraciones de lectura aprobadas en Production; analyze sin incidencias; Deno 21/0; Node cinco archivos aprobados. RIIOTE y golden verificados. Escaneo de secretos sin hallazgos dentro del alcance registrado. CI de la candidata aprobado: [https://github.com/Anthony8724/Cercly/actions/runs/44632085504](https://github.com/Anthony8724/Cercly/actions/runs/44632085504), HEAD a77c3a6c725097696e9c7ff79db6e6ddf93ffec0. Ese commit contiene el mismo código c14e42d de los binarios y agrega documentación; el cierre posterior solo documenta la evidencia. También aprobaron los CI previo y posterior al merge #40.

Advertencias de compilación y firma descritas en PRUEBAS_Y_RIESGOS. Faltan prueba nativa de APK 26, capturas, contraste Console y controles legales/operativos. **Estos artefactos no se distribuyen como versión aprobada.**
