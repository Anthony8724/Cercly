/// Validación de presentación. PostgreSQL vuelve a autorizar y validar todo.
class PropuestaCorreccion {
  static const etiquetas = <String, String>{
    'nombre': 'Nombre',
    'direccion': 'Dirección',
    'categoria_id': 'Categoría',
    'descripcion': 'Descripción',
    'telefono_publico': 'Teléfono público',
    'latitud': 'Latitud',
    'longitud': 'Longitud',
  };

  static Map<String, dynamic>? validar(Object? datos) {
    if (datos is! Map || datos.isEmpty || datos.length > etiquetas.length) {
      return null;
    }
    final result = <String, dynamic>{};
    for (final entry in datos.entries) {
      if (entry.key is! String || !etiquetas.containsKey(entry.key)) {
        return null;
      }
      final item = entry.value;
      if (item is! Map ||
          item.length != 2 ||
          !item.containsKey('anterior') ||
          !item.containsKey('nuevo')) {
        return null;
      }
      final nuevo = item['nuevo'];
      if (nuevo == item['anterior']) return null;
      if (entry.key == 'latitud' || entry.key == 'longitud') {
        if (nuevo is! num ||
            !nuevo.isFinite ||
            nuevo.abs() > (entry.key == 'latitud' ? 90 : 180)) {
          return null;
        }
      } else {
        if (nuevo is! String || nuevo != nuevo.trim()) return null;
        final limite = switch (entry.key) {
          'nombre' => 120,
          'direccion' => 250,
          'telefono_publico' => 20,
          _ => 1000,
        };
        if (nuevo.length > limite ||
            (entry.key == 'nombre' && nuevo.length < 2) ||
            (entry.key == 'direccion' && nuevo.isEmpty)) {
          return null;
        }
        if (entry.key == 'categoria_id' &&
            !RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')
                .hasMatch(nuevo)) {
          return null;
        }
      }
      result[entry.key as String] = {
        'anterior': item['anterior'],
        'nuevo': nuevo,
      };
    }
    return result;
  }
}
