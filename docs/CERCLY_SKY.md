# Cercly Sky — implementación local

## Ambientes y comportamiento

| Ambiente | Hora local | Cabecera | Color de acción |
| --- | --- | --- | --- |
| Amanecer | 05:00–07:59 | lavanda `#454674` → malva `#8B6075` | `#58447E` |
| Día | 08:00–16:29 | azul `#16466F` → celeste `#327494` | `#145987` |
| Atardecer | 16:30–18:59 | violeta `#5C315F` → coral `#9A4D55` | `#853C61` |
| Noche | 19:00–04:59 | azul profundo `#111C3E` → índigo `#3B3D70` | `#3A437C` |

`SkyController` calcula el ambiente con `DateTime.now()` del dispositivo. Consulta el reloj cada 30 segundos mientras la aplicación está en primer plano y vuelve a calcular al reanudarse. Así detecta también cambios manuales de hora y zona horaria, con un máximo de 30 segundos de retraso en primer plano. Configuración → Apariencia guarda el ambiente manual y la opción **Efectos ambientales** en preferencias locales. La opción reutiliza la preferencia anterior de estrellas; el modo Automático es el valor inicial.

`SkyPalette` centraliza colores, gradientes y el tema Material. `SkyBackdrop` acepta opcionalmente una imagen oficial de ciudad; cuando no se proporciona, muestra el gradiente y la decoración vectorial. No hay imágenes de ciudades incluidas. `SkyAmbientGeometry` genera posiciones deterministas, `SkyAmbientPainter` dibuja sol, nubes o estrellas y `SkySurface` comparte un reloj de 8 Hz con su cabecera. Solo se repinta la capa decorativa. Amanecer y Atardecer usan la misma geometría de sol; Día dibuja nubes de movimiento horizontal lento; Noche combina microestrellas y estrellas suaves de cuatro puntas con fases independientes. El fondo queda detrás del contenido y no recibe gestos ni semántica.

Noche utiliza fondo `#0D1731`, superficie `#192645`, texto `#F2F3FF` y acento lavanda `#B49CE8`; Amanecer, Día y Atardecer conservan superficies claras teñidas según su paleta. `ThemeData`, `ColorScheme` y `SkyPalette` aplican tokens a formularios, tarjetas, diálogos, navegación y controles compartidos. **Efectos ambientales** desactiva las formas sin cambiar los colores. Si Android solicita menos movimiento, las formas permanecen estáticas. El reloj se pausa al pasar a segundo plano o al desactivar `TickerMode` en una pantalla oculta. El mapa no usa la capa ambiental ni recibe decoraciones sobre sus teselas.

## Logo e icono Android

Las referencias visuales y la propuesta vectorial fueron aprobadas por el responsable del producto. El isotipo maestro está en `assets/branding/sky/isotipo-master.svg`, con cuatro variantes generadas en `assets/branding/sky/variants/` y vistas previas en `design/cercly-sky/`. Sus colores y diferencias se documentan en [CERCLY_SKY_LOGO_PREVIEW.md](CERCLY_SKY_LOGO_PREVIEW.md). La integración se describe en [CERCLY_SKY_INTEGRACION.md](CERCLY_SKY_INTEGRACION.md).

`assets/branding/cercly_launcher.svg` se conserva como recurso histórico sin uso. Flutter usa los SVG aprobados y Android usa la variante Día generada desde el mismo maestro. El icono del lanzador es estable; el cambio automático de icono sigue sin implementarse.

Android admite iconos adaptativos y `activity-alias` para iconos alternativos. La actualización automática puede quedar reflejada de forma desigual en lanzadores y accesos directos, especialmente sin prueba en HONOR X8b. Por eso este bloque no cambia dinámicamente el icono del lanzador. Una vez recibido el maestro, exportar variantes adaptativas foreground, background y monocromo, validar sus zonas seguras y probar instalación, actualización, accesos directos y lanzador en el dispositivo real antes de considerar un selector de icono.

## Fotografía oficial de Tulcán

Pendiente: recibir la imagen oficial, permiso de uso, punto de recorte para teléfonos, tamaños optimizados y revisión de contraste en los cuatro ambientes. Inyectarla mediante `SkyBackdrop.cityImage` solo en pantallas donde no afecte lectura ni interacción. El valor actual es `null` y utiliza el gradiente.

## Validación y límites

Ejecutar `flutter analyze`, `flutter test` y una compilación APK privada. Probar en un teléfono real la transición de franjas, cambio de zona, reanudación, visibilidad con brillo alto, TalkBack, ahorro de batería y HONOR Launcher. El APK local no valida por sí solo la compatibilidad física con HONOR X8b.

No se cambian Supabase, Google OAuth, migraciones, iconos instalados ni la política de eliminación de cuentas. En el APK privado de evaluación la eliminación permanece deshabilitada hasta desplegar y validar sus componentes de servidor. Producción continúa en **NO-GO**.
