# HONOR — instalación y registro real de RC2

**PENDIENTE. Ningún caso aprobado en dispositivo.** El 19/11/2026 `adb devices -l` no detectó un teléfono. La APK no se recompiló ni cambió durante este bloque.

## Siete pasos

1. Registrar modelo HONOR, Android/MagicOS, fecha y versión instalada de Cercly. Conservar datos locales; no desinstalar ni borrar almacenamiento para forzar la instalación.
2. Usar este archivo existente: `/home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-RC2-CANDIDATA-20261119/Cercly-Produccion-0.1.9+26-RC2.apk`.
3. Comprobar su SHA-256 en el ordenador:

   ```sh
   sha256sum '/home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-RC2-CANDIDATA-20261119/Cercly-Produccion-0.1.9+26-RC2.apk'
   ```

   Debe ser **`812e72ead744d8144e029154be5cabe990c9c030e74d3805fef82a86c5b22f49`**. Si difiere, detener el ensayo.
4. Conectar por USB y aceptar la depuración en tu teléfono. Ejecutar `adb devices -l`; usar el serial que muestre como `device`. Si pone `unauthorized`, aceptar la conexión en pantalla; no compartir el serial en informes públicos.
5. Instalar conservando datos:

   ```sh
   adb -s SERIAL install -r '/home/Anthony/Descargas/Cercly-Produccion-0.1.9+26-RC2-CANDIDATA-20261119/Cercly-Produccion-0.1.9+26-RC2.apk'
   ```

   Debe devolver `Success`. Si hay firma incompatible o downgrade, parar y registrar el error; no usar `-d`, desinstalar ni cambiar claves. Alternativa: transferir ese mismo APK y abrirlo en el teléfono, autorizando solo el instalador elegido; retirar después ese permiso.
6. Abrir Cercly, comprobar versión `0.1.9+26` y package `com.cercly.cercly`, ejecutar la tabla y guardar capturas saneadas. Usar invitado/lecturas públicas; áreas con cuenta solo con identidad QA acordada. No confirmar eliminación ni crear/borrar contenido real en esta APK de Producción.
7. Devolver esta tabla con PASS/FAIL, modelo/SO, evidencia y descripción de fallos. Usar PENDIENTE si no se ejecutó. No incluir correo, tokens, coordenadas privadas ni capturas de otras aplicaciones con datos personales.

## Hoja de resultados

Modelo: ______ · Android/MagicOS: ______ · Fecha: ______ · Instalación previa: ______

| Caso | Acción y resultado esperado | Resultado PASS/FAIL | Evidencia / incidencia |
|---|---|---|---|
| H01 | Instalar y abrir dos veces; sin crash, versión correcta | PENDIENTE | |
| H02 | Denegar ubicación; explorar/errores explicados sin bloqueo accidental | PENDIENTE | |
| H03 | Probar ubicación aproximada y precisa voluntariamente; resultados coherentes | PENDIENTE | |
| H04 | Detalle → Cómo llegar con permiso GPS denegado: aparece confirmación Maps, no ruta interna ni nueva exigencia de GPS | PENDIENTE | |
| H05 | Cancelar confirmación: continúa en Cercly sin abrir Maps | PENDIENTE | |
| H06 | Confirmar: Maps/navegador abre destino correcto y regreso a Cercly funciona; Maps puede pedir su propio permiso | PENDIENTE | |
| H07 | Repetir sin conexión: mensaje/reintento, sin recorrido ficticio ni fallback interno | PENDIENTE | |
| H08 | Radar inicial apagado y notificaciones sin activarse solas, también al reiniciar | PENDIENTE | |
| H09 | Mi cuenta: RIIOTE visible sin recorte; enlace abre https://riiote.org/ o informa fallo | PENDIENTE | |
| H10 | Categorías, mapa, promoción y detalle públicos cargan; atribución visible | PENDIENTE | |
| H11 | Fuente grande/TalkBack y botones Atrás; textos legibles y foco correcto | PENDIENTE | |
| H12 | Abrir privacidad y eliminación; registrar destino y contenido público actual. No enviar formularios ni confirmar borrado | PENDIENTE | |
| H13 | Segundo plano, retorno desde Maps y bloqueo/desbloqueo HONOR sin crash ni pérdida de pantalla | PENDIENTE | |

El token no aparece en la interfaz: no deducir ausencia de tráfico por no ver avisos. H12 puede evidenciar un bloqueo conocido de publicación; registrarlo como FAIL si la URL no ofrece la política completa. Una aprobación de H01–H13 no resuelve por sí sola eliminación alojada, UGC, declaraciones o publicación legal. Guía ampliada: [QA_HONOR_RC2.md](QA_HONOR_RC2.md).
