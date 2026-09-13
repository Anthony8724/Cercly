-- Refinamiento incremental de subcategorias para el mapeo OSM.
-- No modifica las 12 categorias principales ni importa establecimientos.

begin;

insert into public.subcategorias (
  categoria_id,
  nombre,
  slug,
  icono,
  activa,
  orden
)
select
  c.id,
  nueva.nombre,
  nueva.slug,
  nueva.icono,
  true,
  nueva.orden
from (
  values
    (
      'tiendas-supermercados',
      'Centros comerciales y grandes almacenes',
      'centros-comerciales-grandes-almacenes',
      'shopping_mall',
      5
    ),
    (
      'tiendas-supermercados',
      'Floristerías',
      'floristerias',
      'local_florist',
      6
    ),
    (
      'automotriz-movilidad',
      'Venta de vehículos',
      'venta-vehiculos',
      'directions_car',
      5
    ),
    (
      'educacion-papeleria',
      'Jugueterías',
      'jugueterias',
      'toys',
      5
    )
) as nueva(categoria_slug, nombre, slug, icono, orden)
join public.categorias c
  on c.slug = nueva.categoria_slug
 and c.activa
on conflict (slug) do update
set
  categoria_id = excluded.categoria_id,
  nombre = excluded.nombre,
  icono = excluded.icono,
  activa = excluded.activa,
  orden = excluded.orden;

commit;
