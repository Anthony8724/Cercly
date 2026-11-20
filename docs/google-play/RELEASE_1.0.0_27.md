# Cercly 1.0.0+27 para prueba cerrada

**Candidata firmada y verificada localmente. Pendiente de cotejo en Play Console y publicación del cambio legal.**

## Artefacto

- [Cercly-1.0.0-27-CERRADA-CANDIDATA.aab](/home/Anthony/Descargas/Cercly-1.0.0+27-PRUEBA-CERRADA-20261120/Cercly-1.0.0-27-CERRADA-CANDIDATA.aab). **61 432 899 bytes**.
- SHA-256 `8a0ae136227958ccc44ab9741adc21976e5f645b5e6ea62b3f73f26bb0c6c0c3`.
- Fuente `aeda3907509f57937d600a83b43cc06f76528d15` en `release/cercly-1.0-cerrada`, worktree `~/Proyectos/Cercly-release-1.0`. Descendiente de `f90c382` del PR #41 y conserva `143ba7c`, `eca50fb` y `595dbbb`.
- `com.cercly.cercly`, versionName `1.0.0`, versionCode `27`, min SDK 24, compile/target SDK 36. Código de compilación explícito 27, provisional hasta verificar los códigos de Play.
- Certificado de carga RSA 4096 con SHA-256 `F0:49:86:57:B1:F4:C7:B7:4C:9F:88:9F:44:B7:2A:57:60:98:8F:BD:64:0A:94:D1:D9:A1:E2:F1:C4:85:66:D5`. Coincide con el certificado local previo RC2.
- `bundletool 1.18.3 validate`, `jarsigner -verify`, manifiesto y configuración del AAB verificados. ABIs arm64-v8a, armeabi-v7a y x86_64. Segmentos ELF64 cargables alineados al menos a 16 KB y ZIP del APK universal de inspección aprobado con `zipalign -c -P 16 4`. La inspección no constituye instalación en dispositivo.
- Permisos: Internet, red, ubicación aproximada/precisa de primer plano, notificaciones, vibración, wake lock, recepción FCM y un permiso propio de receptores. Sin AD_ID, ubicación de fondo, SMS, micrófono ni contactos.
- 424 entradas escaneadas para material privado y configuración no autorizada. Confirmados Production, UGC y RIIOTE. Sin URL ni paquete de Staging, endpoints de HeiGIT/ORS, tabla de campañas pagadas o RPC de confirmación de cobros en ese escaneo. Se usaron únicamente la URL y clave publicable de Production. El panel de campañas pagadas y su consulta quedaron excluidos de la aplicación de distribución. Las promociones orgánicas permanecen.

El build usó `flutter pub get --offline --enforce-lockfile` y `flutter build appbundle --release --no-pub --build-name=1.0.0 --build-number=27 --dart-define-from-file=<configuración privada local>`. La firma usa el keystore existente. Se conservó RC2 y se volvió a comprobar su hash.

## Supabase Producción

Proyecto verificado `aimubazregckmjchnszf`, PostgreSQL 17.6. Dos aplicaciones versionadas con el CLI y `--skip-vault`. Cada dry run enumeró exactamente la migración de su lote. El historial alojado pasó de 41 a 43 entradas:

1. `20261119231916_reconocer_cuota_rutas_eliminacion.sql` · SHA-256 `e9b9c454edcbcdd06ac6fbbe59c595ec41985129af9e6e7a508b239ada4bad9f`.
2. `20261120034446_controles_ugc_cercly.sql` · SHA-256 `294c65dd664dbd0a0861110c88c6fe73235acc9c54c073b09e37af79a6e003fe`.

La copia lógica privada previa se guardó bajo `~/RespaldosPrivados/Cercly/Production/pre-ugc-20261120T042255Z`. El archivo mide 729 420 bytes y su SHA-256 es `6bb09dbf17a9293c8ee4761bf1db50b73088b28881de1ccdf554b2848a5012d7`. Se restauró estructura y datos en un contenedor sin red, comprobando 37 cuentas, 37 perfiles, 41 objetos de Storage como metadatos y 41 migraciones previas. La restauración de prueba excluyó dueño y ACL. El respaldo no contiene los bytes de fotos. Producción conservó los dueños y permisos existentes, verificados por catálogo. `storage.objects` conserva a `supabase_storage_admin`, el esquema UGC aplica RLS, los clientes no tienen acceso directo al esquema y el rol anónimo no puede moderar. El detector de dependencias devuelve falso para el UUID inexistente.

| Evidencia | Resultado |
| --- | --- |
| Flutter | 479 aprobadas, 21 omitidas y 0 fallidas. Analizador limpio. |
| SQL local con 17.6 | 802 comprobaciones de la base y 40 de UGC. También se ejecutaron las dos migraciones sobre el respaldo restaurado. |
| Eliminación HTTP alojada | 8 aprobadas. Pasó el rechazo anónimo, HTTP 200 para la cuenta simple sintética, ausencia de Auth/perfil/sesiones/refresh y rechazo de las credenciales anteriores. |
| UGC HTTP alojada | 27 aprobadas. Aceptación verificada, subida de foto, `RETURNING` para foto y promoción de prueba inactiva, RLS ajeno, bloqueo, retirada y trazabilidad. El denunciante pasó a revisión con HTTP 202. La limpieza posterior usó solo los fixtures con IDs generados. Cero fichas o archivos QA residuales. Una identidad sintética de moderación quedó en revisión por su historial de aprobación. |
| Integridad | Huella del conjunto de cuentas preexistentes coincide con la del respaldo. Cero campañas destacadas en el catálogo consultado. |
| Web | Privacidad del PR #17 responde 200. El agregado mínimo UGC `ace22ad` se preparó localmente sobre `54d4ad4`, con Next build y lint aprobados. Pendiente integración pública. |

Las versiones antiguas de la app que carecen de aceptación UGC pueden consultar el catálogo conforme a permisos, pero el servidor rechaza sus escrituras que requieren normas. El flujo de revisión permanece activo para datos compartidos. La prueba no demuestra la supresión integral de historiales reales de moderación.

Evidencias saneadas en `~/Proyectos/Cercly-evidencias-1.0/cierre-produccion`. La compilación emitió avisos de futuro soporte Kotlin de Firebase y opciones Java obsoletas. Bundletool y la firma aprobaron.

## Antes de cargar manualmente

1. En **Probar y lanzar → Últimos lanzamientos y paquetes → Todas las versiones de la app**, confirmar que el código 27 nunca se usó y es superior al código que deban recibir los testers. Si hace falta otro, recompilar desde el mismo SHA con el siguiente código válido. El SHA del archivo cambia.
2. En **Integridad de la app → Firma de aplicaciones**, cotejar la huella con el **certificado de clave de carga**. El certificado administrado por Play corresponde a la APK de distribución y se verifica separadamente.
3. Integrar el cambio mínimo de privacidad después de autorización, verificar las URL públicas y validar la atención del canal externo de supresión. Revisar solo los campos de Contenido de la app afectados. Seguridad de los datos debe incluir aceptación, denuncias, bloqueos y auditoría. Confirmar que la ficha y las cuentas del revisor describen el comportamiento habilitado.
4. En **Probar y lanzar → Pruebas → Prueba cerrada**, configurar país, lista de Google Accounts y contacto de feedback. Crear un lanzamiento, cargar el AAB y revisar las advertencias de Console. El envío a revisión y la apertura del track corresponden al titular. Comprobar con una cuenta inscrita que Play entrega el código correcto y ejecutar la matriz Android en el dispositivo.
5. Si la cuenta es personal y posterior al 13/11/2023, conservar al menos 12 testers inscritos durante 14 días consecutivos antes de solicitar acceso a Producción. Ver [requisitos de prueba cerrada](https://support.google.com/googleplay/android-developer/answer/14151465?hl=es).
