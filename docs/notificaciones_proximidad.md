# Notificaciones de promociones por proximidad

## Alcance del MVP

El monitor funciona mientras Cercly está abierta y activa. Comprueba la
ubicación al iniciar, al volver al primer plano y cada dos minutos. Android
puede detener la aplicación cuando queda en segundo plano o se cierra; este
MVP no instala un servicio permanente ni geofencing.

Solo se consideran promociones activas y vigentes de establecimientos
aprobados y publicables. `PromocionPublicaService.listarCercanas` calcula la
distancia y aplica `radio_alerta_metros`.

Una promoción se notifica al entrar en su radio. Permanecer dentro no genera
repeticiones. Para volver a notificar es necesario salir del radio, volver a
entrar y que hayan transcurrido al menos dos horas desde el aviso anterior.

El momento de la última notificación se guarda localmente en el dispositivo.
Por eso, cerrar y volver a abrir Cercly ya no reinicia el cooldown ni provoca
que la misma promoción se muestre otra vez inmediatamente.

## Prueba manual en Android Emulator

1. Obtener dependencias y validar el proyecto:

   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   ```

2. Iniciar `emulator-5554` y ejecutar Cercly con el archivo remoto local del
   desarrollador (este archivo no se versiona):

   ```powershell
   flutter run -d emulator-5554 --dart-define-from-file=./config/supabase.remote.json
   ```

3. Simular una ubicación de Tulcán. El emulador recibe primero longitud y
   después latitud:

   ```powershell
   adb -s emulator-5554 emu geo fix -77.7172 0.8116
   ```

4. Conservar Cercly en primer plano y conceder ubicación y notificaciones.

5. Usar una promoción activa y vigente cuyo establecimiento esté aprobado y
   publicable. Configurar `radio_alerta_metros` para que la ubicación simulada
   quede dentro del radio.

6. Verificar el aviso `Promoción cerca de ti`, la vibración y que no vuelva a
   aparecer en cada comprobación mientras el usuario permanezca dentro.

7. Para ensayar una nueva entrada con la misma promoción, espera el cooldown y
   mueve el emulador fuera y después dentro del radio. Reiniciar la aplicación
   ya no borra el cooldown guardado localmente.

No se requieren cambios de base de datos, `service_role` ni credenciales
adicionales.
