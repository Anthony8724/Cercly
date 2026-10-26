# Cercly Sky — propuesta vectorial para aprobación visual

## Autoridad visual y alcance

Referencias aprobadas: `design/referencias/cercly-sky-logo-aprobado.png` y `design/referencias/cercly-sky-pantallas-aprobadas.png`. Se revisaron visualmente antes de dibujar. La primera muestra el isotipo C-pin, el punto central, las cuatro paletas, el área de seguridad y la palabra Cercly redondeada. La segunda muestra composiciones de bienvenida y autenticación.

Esta página documenta la primera fase de vistas previas. El responsable del producto aprobó visualmente la propuesta vectorial y autorizó su integración en la segunda fase. El estado de integración y su APK se documentan en [CERCLY_SKY_INTEGRACION.md](CERCLY_SKY_INTEGRACION.md).

## Recursos

- Maestro: `assets/branding/sky/isotipo-master.svg`, `viewBox="0 0 256 256"`. Una ruta cerrada forma la C y la punta del pin; un círculo independiente forma el punto de ubicación. No contiene raster ni filtros.
- Generador: `tool/generate_cercly_sky_brand.py`. Lee la ruta y el círculo del maestro y produce todas las variantes. La geometría no se mantiene en cuatro copias manuales.
- Vistas previas: `design/cercly-sky/previews/comparativa-cercly-sky.png`, junto a PNG individuales.
- SVG preliminares: `design/cercly-sky/svg/` contiene isotipo transparente, logotipo horizontal, icono normal, frente y fondo adaptativos, y monocromo para cada ambiente.
- Tipografía del logotipo horizontal: Comfortaa Bold, [SIL Open Font License 1.1](../assets/branding/sky/fonts/OFL.txt). El archivo está en `assets/branding/sky/fonts/Comfortaa-Bold.otf`. Flutter registra la fuente y compone el logotipo horizontal con el SVG del isotipo y texto nativo. Los SVG horizontales de diseño usan texto vectorial dependiente de esa fuente.

## HEX propuestos para el logo

| Ambiente | Isotipo: inicio → centro → fin | Fondo del icono: inicio → fin | Palabra sobre fondo claro |
| --- | --- | --- | --- |
| Amanecer | `#20A7F5` → `#887AF0` → `#FF9C78` | `#D0D7FF` → `#FFD6C3` | `#14265A` |
| Día | `#0066ED` → `#17B9F5` → `#0067DC` | `#E8F6FF` → `#BEEBFF` | `#102A62` |
| Atardecer | `#FFB148` → `#F05586` → `#7935D1` | `#FFF0D8` → `#FFC7D5` | `#321C62` |
| Noche | `#E1C4FF` → `#8F92FA` → `#5C8BFF` | `#283D83` → `#0B1E4D` | `#FFFFFF` sobre fondo oscuro |

Estos son colores de **marca preliminares** derivados de las referencias. `SkyPalette` controla la interfaz y no se cambió en esta fase.

## Comprobaciones de esta fase

`python3 tool/generate_cercly_sky_brand.py` renderiza los SVG a PNG, parsea los cinco elementos SVG por variante y verifica que ruta y círculo coincidan exactamente con el maestro. También compara las máscaras alfa rasterizadas de los cuatro isotipos y verifica que cada píxel del frente adaptativo quede dentro de un círculo seguro de radio 144 en lienzo 432 × 432. Resultado: cuatro geometrías idénticas, SHA-256 de geometría `29b767b0c21db943f9e3617365df7206c9de4fa851445972eb52a7b782392327`.

La lámina se examinó visualmente después del renderizado. Presenta isotipos transparentes, iconos con fondo, logotipos horizontales y los iconos a 24, 48 y 96 px. El símbolo permanece reconocible a 24 px; la lectura final en los lanzadores Android y en HONOR X8b sigue pendiente de prueba real. Los gradientes son estáticos y no incorporan animación.

## Diferencias deliberadas respecto de las imágenes

- Se simplificaron brillos, reflejos, halos y bordes irregulares propios de la imagen generada para obtener contornos limpios y reproducibles. La C, la punta de pin y el punto central conservan su composición.
- Los fondos de Día y Atardecer son más claros que algunos ejemplos de la referencia para separar el isotipo del fondo a tamaños pequeños.
- Comfortaa Bold aproxima la palabra redondeada de la referencia sin copiar sus deformaciones; la tipografía exacta de la imagen no se conoce.
- No se incluyeron nubes, ciudades, edificios ni fotografías de las pantallas de ejemplo. La futura bienvenida usará los gradientes existentes hasta disponer de una fotografía oficial de Tulcán con autorización.
- El monocromo es una silueta limpia de la misma geometría, sin gradientes. El splash y las capas Android finales se prepararán para integración solo tras la aprobación visual.

## Decisión de integración

La propuesta fue aprobada visualmente. Se autorizó reemplazar el logo provisional en Flutter, el splash y el icono estable Día del lanzador. El cambio automático del icono por horario sigue fuera de alcance hasta validar lanzadores, accesos directos y actualizaciones en dispositivos reales.
