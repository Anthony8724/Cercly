# Alcance definitivo del MVP de Cercly

**Versión:** 1.0  
**Responsable:** Anthony López  
**Duración prevista:** 5 semanas  
**Zona piloto:** Tulcán, Carchi, Ecuador

## 1. Propósito

El MVP de Cercly permitirá que una persona consulte establecimientos cercanos a su ubicación y conozca promociones activas. La primera versión se enfocará en demostrar que la geolocalización, la consulta de establecimientos, el mapa y las alertas de proximidad funcionan de forma integrada.

## 2. Usuarios del MVP

### Usuario de la aplicación

Persona que utiliza Cercly para descubrir establecimientos y promociones cercanas.

### Equipo administrador

Equipo del proyecto que registra y mantiene manualmente la información inicial en Cloud Firestore. El MVP no incluirá todavía un panel administrativo independiente.

## 3. Funciones obligatorias

### 3.1 Ubicación

- Solicitar permiso para acceder a la ubicación del dispositivo.
- Obtener las coordenadas actuales del usuario.
- Informar claramente cuando el permiso sea rechazado o la ubicación no esté disponible.

### 3.2 Establecimientos cercanos

- Consultar establecimientos almacenados en Cloud Firestore.
- Mostrar nombre, categoría, dirección, coordenadas e imagen cuando esté disponible.
- Calcular la distancia aproximada entre el usuario y cada establecimiento.
- Ordenar los establecimientos de menor a mayor distancia.

### 3.3 Mapa y listado

- Mostrar la ubicación del usuario en un mapa.
- Mostrar marcadores de los establecimientos registrados.
- Permitir alternar o navegar entre el mapa y el listado de establecimientos.

### 3.4 Filtros

- Filtrar establecimientos por categoría.
- Incluir inicialmente categorías como restaurantes, cafeterías, tiendas y minimarkets.
- Permitir regresar a la vista de todos los establecimientos.

### 3.5 Detalle del establecimiento

- Mostrar nombre, categoría, dirección, descripción, distancia e imagen.
- Mostrar las promociones activas asociadas.
- Incluir la opción **Cómo llegar** para abrir Google Maps u otra aplicación compatible.

### 3.6 Promociones

- Mostrar título, descripción y vigencia de la promoción.
- Mostrar únicamente promociones activas y dentro de sus fechas de vigencia.
- Relacionar cada promoción con un establecimiento.

### 3.7 Alerta de proximidad

- Detectar cuando el usuario se encuentre dentro del radio definido para una promoción.
- Generar una notificación local visible y una vibración.
- Al pulsar la notificación, abrir el detalle correspondiente dentro de Cercly.
- Evitar notificaciones repetidas continuamente para la misma promoción.

### 3.8 Datos iniciales

- Utilizar establecimientos verificables de Tulcán para las pruebas.
- Registrar categorías, establecimientos y promociones ficticias o autorizadas.
- No almacenar contraseñas, datos sensibles ni información personal innecesaria.

## 4. Requisitos de calidad mínimos

- La aplicación deberá ejecutarse en un teléfono Android de prueba.
- La interfaz deberá ser comprensible y mantener una identidad visual consistente.
- Los mensajes de error deberán orientar al usuario.
- La información de Firestore deberá consultarse sin exponer credenciales privadas.
- El código se almacenará en GitHub y se integrará mediante ramas y Pull Requests.
- Las funciones principales deberán probarse con ubicación real en Tulcán.
- Se utilizará caché local básica únicamente cuando sea viable dentro de las cinco semanas.

## 5. Fuera del alcance del MVP

Las siguientes funciones se aplazan para versiones futuras:

- Aplicación para iOS.
- Registro e inicio de sesión de usuarios.
- Perfiles personalizados.
- Favoritos y reseñas.
- Calificaciones y comentarios.
- Panel web para propietarios de establecimientos.
- Registro autónomo de comercios.
- Pagos, compras o reservas.
- Chat entre usuarios y establecimientos.
- Recomendaciones mediante inteligencia artificial.
- Historial avanzado de ubicaciones.
- Rutas internas o navegación paso a paso.
- Expansión operativa a otras ciudades.
- Notificaciones enviadas desde un servidor.
- Analítica empresarial avanzada.
- Funcionamiento completamente sin conexión.

## 6. Datos principales

El MVP trabajará con las siguientes colecciones de Cloud Firestore:

- `categorias`
- `establecimientos`
- `promociones`

No se incluirá una colección de usuarios mientras el MVP no tenga autenticación.

## 7. Criterios de finalización

El MVP se considerará terminado cuando se pueda demostrar el siguiente recorrido en un teléfono Android:

1. Abrir Cercly.
2. Autorizar la ubicación.
3. Visualizar la posición actual y establecimientos de Tulcán.
4. Ordenar o consultar los establecimientos según distancia.
5. Filtrar por categoría.
6. Abrir el detalle de un establecimiento.
7. Consultar una promoción activa.
8. Abrir la ruta mediante **Cómo llegar**.
9. Recibir una alerta de proximidad durante una prueba controlada.

Además, la versión deberá estar integrada en GitHub, contar con documentación básica y no presentar errores que impidan completar este recorrido.

## 8. Control de cambios

Cualquier función nueva que no sea necesaria para cumplir los criterios anteriores deberá registrarse como mejora futura. Su incorporación al MVP requerirá aprobación del equipo y una revisión del tiempo disponible.
