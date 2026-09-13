alter table public.categorias
add column slug varchar(80) not null unique
check (
  slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
);

insert into public.categorias (
  nombre,
  slug,
  icono,
  activa,
  orden
)
values
  (
    'Restaurante',
    'restaurantes',
    'restaurant',
    true,
    1
  ),
  (
    'Cafetería',
    'cafeterias',
    'local_cafe',
    true,
    2
  ),
  (
    'Tienda',
    'tiendas',
    'store',
    true,
    3
  ),
  (
    'Minimarket',
    'minimarkets',
    'shopping_basket',
    true,
    4
  ),
  (
    'Otro',
    'otros',
    'category',
    true,
    5
  )
on conflict (slug)
do update set
  nombre = excluded.nombre,
  icono = excluded.icono,
  activa = excluded.activa,
  orden = excluded.orden;