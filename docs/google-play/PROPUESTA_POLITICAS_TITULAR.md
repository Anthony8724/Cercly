# Propuesta concreta de políticas — aprobación del titular pendiente

19/11/2026. Documento interno; no es una política publicada ni una aceptación contractual. No habilita formularios, portal, despliegues ni eliminación de datos reales.

## Decisión ya registrada: alcance exacto de 90 días

PR #16, fusionado por el titular en `deeb4d654f37b25a692dce58377567994be68504`, aprueba hasta **90 días después del cierre documentado**, con excepciones justificadas, exclusivamente para **consultas ordinarias de soporte e incidencias técnicas resueltas**. No incluye solicitudes de derechos, cuentas, imágenes, auditorías, registros de pago, logs ni respaldos. Falta implantar/verificar el borrado en Formspree, Proton y copias. La política pública sigue sin prometer ese plazo.

## Texto y decisiones propuestas

| Categoría | Propuesta que puede aprobar el titular | Alternativa o límite pendiente |
|---|---|---|
| Cuenta activa | Conservar identidad/perfil y preferencias mientras se presta el servicio solicitado. Al recibir una solicitud verificada, inventariar y suprimir los datos propios que no deban conservarse justificadamente | No convertir inactividad en borrado automático sin decidir aviso, plazo y mecanismo. No aplicar 90 días |
| Cuenta eliminada | Confirmar eliminación solo después de comprobar Auth, perfil, preferencias, cuota, sesiones y asociaciones. No conservar copias de correo, teléfono, UUID ni hashes identificables «por si acaso» | Las dependencias compartidas necesitan un plan de minimización y una decisión documentada. El recibo anónimo local previsto no acredita anonimización de todos los historiales |
| Imágenes | Retirar mediante API Storage los archivos propios cuyo borrado esté autorizado y comprobar metadatos y acceso posterior. Separar la eliminación de una fotografía de la eliminación de cuenta | La presencia de fotos/datos compartidos detiene hoy el borrado automático. Transferir propiedad, conservar una foto ajena o borrar contenido compartido exige titularidad y decisión específica; no borrar un negocio completo por defecto |
| Negocios y promociones | Conservar la ficha/imagen solo para la finalidad publicada y con responsable autorizado; resolver cada vínculo cuando se elimina una cuenta | Definir si una ficha puede continuar por su fuente OSM o nuevo responsable, retirar contactos personales innecesarios y comunicar el resultado. No asumir autorización de terceros |
| Respaldos | Adoptar un ciclo de expiración basado en la configuración real de cada proveedor, limitar acceso y uso a recuperación y volver a aplicar las supresiones si se restaura una copia | Alternativa: infraestructura con borrado selectivo verificable. Antes de elegir, inventariar Supabase, Storage, Vercel y copias/exportaciones. No anunciar un número ni eliminación instantánea sin evidencia |
| Solicitudes de derechos y eliminación | Conservar solo el expediente mínimo necesario para tramitar y acreditar el resultado; separar mensaje original de constancia mínima, con acceso restringido | Elegir fundamento, responsable, momento de supresión y duración por categoría tras revisión jurídica. No heredar los 90 días del soporte ordinario ni guardar documentos/OTP/contraseñas |
| Auditorías y referencias económicas | Limitar referencia/actor/contenido al propósito demostrado; suprimir o desvincular datos personales cuando ya no se necesiten | Una obligación concreta puede justificar retención limitada, pero debe identificarse y fijar alcance/plazo. El código no demuestra una obligación fiscal universal ni conservación ilimitada |
| Logs de proveedores | Inventariar campos y configuración, minimizar IP/coordenadas/tokens y restringir acceso | No se acreditan los plazos efectivos. No declarar procesamiento efímero ni exclusión de Data safety sin verificar |
| Canal externo | Atención por correo con registro mínimo, verificación segura mediante recuperación/reauth en canal controlado y confirmación al titular verificado | Alternativa: portal OTP/Turnstile después de ensayo integral y autorización. No habilitar el portal actual ni pedir credenciales por correo. Definir responsable y plazo de respuesta aplicable con revisión jurídica |

### Texto propuesto para la política una vez implementado y aprobado

«Conservamos los datos necesarios para prestar las funciones que solicitas y tramitar tus solicitudes. Cuando pides eliminar tu cuenta verificamos la titularidad, revisamos los datos propios y las relaciones compartidas y comunicamos qué se ha eliminado y qué información debe conservarse, por qué y durante cuánto tiempo. Las fotografías se gestionan por separado mediante el servicio de almacenamiento. Desinstalar la aplicación no solicita el borrado remoto. Los respaldos y registros técnicos siguen los ciclos documentados de cada proveedor; si se restaura una copia se deben volver a aplicar las supresiones correspondientes.»

Este párrafo es una **propuesta de proceso**, no una garantía actual: completar ciclos reales, excepciones y procedimiento antes de trasladarlo a la página pública. No sustituye una revisión jurídica. El resto del contenido preparado en `/privacidad`, `/eliminar-cuenta` y `/terminos` sigue siendo un borrador con lagunas explícitas.

## Aprobaciones independientes necesarias

1. Confirmar domicilio legal de contacto y jurisdicción, sin inferirlos de la residencia general.
2. Aprobar las reglas anteriores por categoría y asignar responsable operativo; probar excepciones, restauraciones y eliminación de archivos.
3. Aprobar términos sobre contenido permitido/prohibido y moderación. RC2 no acredita aceptación previa de términos, denuncia general ni bloqueo de aportantes: el texto web no crea esos controles.
4. Confirmar si destacadas se venden como espacios publicitarios y clasificar anuncios/pagos. No asumir ausencia de anuncios por carecer de SDK publicitario.
5. Decidir público/edades y revisar IARC; la propuesta de adultos no es una clasificación concedida ni una exención UGC.
6. Aprobar publicación web y habilitación del canal de derechos por separado. Publicar la política no despliega la corrección SQL ni prueba la eliminación.

Para registrar la decisión: categoría, opción/texto aprobado, responsable, fundamento a revisar, fecha, evidencia de implementación y estado de publicación. No registrar datos personales de solicitantes en Git.
