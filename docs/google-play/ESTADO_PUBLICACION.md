# Estado de publicación — candidata RC2

Revisión: 19/11/2026. **NO-GO también para la prueba cerrada de Google Play.** Los bloqueos técnicos resueltos no sustituyen la publicación autorizada de documentos, una eliminación operativa ni las decisiones del titular. Último cierre: [CIERRE_BLOQUEOS_RC2.md](CIERRE_BLOQUEOS_RC2.md).

## Fuentes y alcance

- develop conserva `3ef19a820263c2add7db27a78d43570dd5f52cfd`; PR #40 fusionado, RIIOTE incluido. No se modificó main.
- Android: rama release/play-store-0.1.9-26, PR #41 abierto en borrador. Código compilado RC2: `40c1f2fd5af3027ccd896e03ef1a17e848068069`. Los commits posteriores solo documentan resultados.
- Web: compliance/play-privacy-routes-20261119, PR #15 abierto en borrador. Código de páginas revisado `a1f721bc8ba6f02d489fe02cc3b45281872783c2`; HEAD final `1cd56445268f2afecfa793c73312a120f7afbf39` incorpora la base concurrente y su evidencia sin cambiar páginas. No publicada ni fusionada.
- La candidata anterior de 0.1.9+26 (c14e42d) y +25 se conservan; sus hashes no corresponden a RC2. VersionCode 26 continúa provisional, sin acceso/evidencia de Console.

## Tabla final

| Control | Estado | Evidencia y límites |
|---|---|---|
| Detección de concurrencia | APROBADO | HEAD Android a7f11f2 y web f21b059 coincidían con remotos antes de editar; se vuelve a verificar antes de push |
| HeiGIT en la candidata nueva | APROBADO | Bloqueo por código antes de sesión/RPC/red y pruebas de cero envío. Cómo llegar abre Google Maps solo con destino y confirmación |
| Reactivar rutas internas | BLOQUEADO | Código conservado; exige proveedor/condiciones válidas y revisión, no un flag ni consentimiento |
| Flutter | APROBADO | 468 aprobadas, 21 omitidas, 0 fallidas; nueve integraciones públicas adicionales aprobadas aparte |
| Deno / Node de servidor | APROBADO | 21 Deno y 37 Node, sin llamadas reales al proveedor |
| SQL de eliminación y seguridad | APROBADO | 802 aserciones, 30 suites, contenedor nuevo sin red y fixtures sintéticos; no prueba GoTrue/Storage HTTP |
| Guarda de eliminación desplegada | BLOQUEADO | FK de cuota no reconocida fuerza revisión incluso sin dependencias personales; migración corregida solo local |
| Eliminación HTTP local real | APROBADO | 43/43: Auth/perfil/relaciones/sesiones/refresh, Storage por API, aprobación revisada y datos ajenos intactos; sin dobles |
| Eliminación alojada y canal externo | PENDIENTE | El ensayo local no acredita gateway Edge, versiones/configuración alojadas, correo/OTP o respaldos; no se cambió Staging/Production |
| Web preparada | APROBADO | Última revisión: 32 pruebas, cinco rutas HTTPS locales 200 y nueve vistas de las tres páginas legales; anterior auditoría completa de 15 vistas conservada |
| Web publicada | BLOQUEADO | HEAD público: /privacidad 307 a portada, /eliminar-cuenta 200 y /terminos 404; no se despliega sin autorización |
| SDK/firma/estructura y secretos RC2 | APROBADO | Package com.cercly.cercly, versión 26, compile/target 36, min 24, misma firma; escaneo definido sin hallazgos; bundletool/zipalign/ELF64 |
| CI de cambios RC2 | APROBADO | [Android 44639065759](https://github.com/Anthony8724/Cercly/actions/runs/44639065759), SHA 48257b854ea14ef20b1dcf0afeb65fd1a3f8249b: análisis/pruebas y APK debug Staging. [Web 44638985403](https://github.com/Anthony8724/cercly-web/actions/runs/44638985403), SHA a1f721b: quality. Cambios posteriores solo documentales/prueba de retención; se validan localmente |
| HONOR y capturas nuevas | PENDIENTE | adb no encontró dispositivos. No se reinstaló ni borró nada en un teléfono |
| Data safety / anuncios / UGC / público / retención | PENDIENTE | Propuestas con evidencia; no se consultaron respuestas reales de Console ni se enviaron formularios |
| Controles CGU para distribución | BLOQUEADO | No se acreditan aceptación previa de términos ni denuncia/bloqueo general para aportes públicos; requiere implementación y pruebas, no solo decisión de formulario |
| Cuenta Play / code 26 / certificado / prueba cerrada | PENDIENTE | Ver INSTRUCCIONES_PLAY_CONSOLE.md y PLAN_12_TESTERS_14_DIAS.md |

El bloqueo contractual se evita para esta candidata, no se declara resuelto para el servicio alojado ni para versiones anteriores. El backend de rutas existente sigue sin cambios. Supabase continúa siendo el backend; Firebase no lo sustituye.

## Bloques y commits

| Bloque | Resultado | Commit |
|---|---|---|
| A | Mapas externos y barreras de transmisión/compilación | eed4243 |
| C | Reconocer solo FK exacta de cuota; 15 regresiones nuevas y 802 aserciones globales | 40c1f2f |
| B | Política/términos/eliminación fieles a RC2 y CSS completo | a1f721b (web) |
| D/E | Declaraciones, QA HONOR, plan cerrado, informes y artefactos | Ver git log de release y RELEASE_0.1.9_26_RC2.md |

## Documentos activos

- [Rutas y alternativas](RESOLUCION_RUTAS.md).
- [Auditoría de eliminación y propuesta de corrección](AUDITORIA_ELIMINACION_INTEGRAL.md).
- [Declaraciones recomendadas](DECLARACIONES_PLAY_RECOMENDADAS.md), [inventario de datos](SEGURIDAD_DATOS.md), [política propuesta](POLITICA_PRIVACIDAD.md).
- [Pasos de Console](INSTRUCCIONES_PLAY_CONSOLE.md), [QA HONOR](QA_HONOR_RC2.md), [plan cerrado](PLAN_12_TESTERS_14_DIAS.md).
- [Release actual](RELEASE_0.1.9_26_RC2.md), [pruebas](PRUEBAS_Y_RIESGOS.md), [decisiones del titular](DECISIONES_TITULAR.md), [pendientes](PENDIENTES_MANUALES.md).

No se aplicaron migraciones remotas ni se desplegó Producción, no se crearon/eliminaron cuentas reales, no se compró ni contrató un servicio y no se fusionaron #41/#15. GitHub/Vercel generaron las comprobaciones y previews configuradas al actualizar ramas. test/failures/ original permanece intacto y fuera de Git.

En la continuación final no se sube la nueva rama web: un push dispara Preview, y la instrucción actual prohíbe desplegar la web sin autorización. Sus cambios finales quedan en commit local; PR #15 remoto conserva 1cd5644. Se precisaron permisos de ubicación y comunicaciones técnicas de Firebase, y se aprobaron 32 pruebas/nueve vistas de las tres páginas. Ver PUBLICACION_WEB_LEGAL.md para la secuencia #15 → compliance/play-readiness y #6 → main; la segunda integración afecta también portada/soporte/navegación.

Concurrencia final: la base web avanzó a deeb4d654f37b25a692dce58377567994be68504 por el PR #16, fusionado por el titular. Se incorporó sin conflictos a la rama #15, sin fusionar ese PR ni modificar páginas/configuración ya compiladas. Revalidación local: 32 pruebas, cinco rutas HTTPS y 15 vistas aprobadas. Registra aprobación de hasta 90 días para soporte ordinario cerrado e incidencias resueltas; ejecución en Formspree/Proton y demás categorías siguen pendientes. No se anuncia el plazo como práctica pública.
