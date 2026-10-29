# Alertas locales de promociones cercanas

## Alcance y privacidad

Las alertas están apagadas inicialmente y son independientes de «Priorizar
establecimientos con promociones». Al activarlas, Cercly solicita permiso de
ubicación en primer plano y permiso de notificaciones. No solicita ubicación
en segundo plano.

Con las alertas activas, el monitor obtiene una posición cada cinco minutos
mientras la aplicación está abierta y en primer plano. Solo acepta posiciones
con precisión de hasta 100 metros y antigüedad máxima de dos minutos. Las
coordenadas se usan en memoria para filtrar promociones cercanas; no se
persisten ni se envían al backend. El historial local almacena solo IDs de
promoción y horas de notificación para limitar repeticiones.

Solo se consultan promociones activas y vigentes en establecimientos aprobados
y publicables. El radio efectivo es el menor entre el radio que eligió la
persona y `radio_alerta_metros` de la promoción. Una notificación muestra el
nombre del negocio y un resumen de la promoción. Android marca el contenido
como privado en la pantalla bloqueada; tocarla abre el detalle público del
establecimiento si sigue disponible.

Para evitar avisos repetidos, se envía una alerta por ciclo, no se vuelve a
notificar mientras la persona permanezca dentro de la misma zona, se aplica
un cooldown de dos horas por promoción, un intervalo global de 15 minutos y
un máximo de tres alertas por cada periodo móvil de 24 horas. Salir y volver a
entrar permite una nueva alerta cuando se cumplen esos límites.

El monitor se detiene al pasar a segundo plano. No se garantiza la entrega con
la aplicación minimizada, pantalla bloqueada, retirada de recientes, detenida
por el sistema, forzada a detener o tras reiniciar el teléfono. Sin conexión
no se consultan promociones ni se emiten nuevas alertas. La batería depende de
los servicios de ubicación del dispositivo; no se ha medido consumo real en
teléfonos.

## Prueba manual en Android Emulator o teléfono

1. Activar «Alertas de promociones cercanas» en Configuración y conceder
   ubicación precisa y notificaciones. Cercly no pide esos permisos antes de
   que la persona active el control.
2. Usar una promoción de prueba que ya exista en Staging, vigente y asociada a
   un establecimiento aprobado y publicable. No crear datos remotos de prueba
   sin autorización.
3. En un emulador Android, simular una ubicación compatible con la promoción;
   por ejemplo, si la promoción sintética de Staging está en Tulcán:

   ```sh
   adb emu geo fix -77.7172 0.8116
   ```

4. Mantener Cercly visible y en primer plano. La ubicación simulada puede
   requerir repetirse para que el sistema la considere reciente.
5. Comprobar que la promoción está dentro del radio más corto entre el radio
   personal y el configurado por la promoción. Esperar como máximo un ciclo
   de cinco minutos.
6. Verificar el canal «Promociones cercanas», el aviso y la navegación al
   detalle. Repetir una evaluación dentro de la misma zona y confirmar que no
   aparece una segunda alerta.
7. Para probar reingreso, salir del radio y volver a entrar; la misma
   promoción respeta el cooldown de dos horas. El límite global permite como
   máximo una alerta cada 15 minutos y tres por 24 horas.
8. Apagar el control y comprobar que no se vuelve a consultar ubicación.

La APK de este bloque debe construirse con `CERCLY_STAGING=true` y el archivo
local ignorado `config/supabase.staging.local.json`. No usar credenciales de
Production ni incluir secretos de servidor en el cliente.
