-- Pruebas pgTAP de la migracion incremental de taxonomia OSM.

begin;

select plan(3);

select is(
  (select count(*)::bigint from public.categorias where activa),
  12::bigint,
  'el refinamiento conserva exactamente 12 categorias principales activas'
);

select is(
  (
    select count(*)::bigint
    from public.subcategorias
    where activa
      and slug in (
        'centros-comerciales-grandes-almacenes',
        'venta-vehiculos',
        'jugueterias',
        'floristerias'
      )
  ),
  4::bigint,
  'existen las cuatro subcategorias nuevas y estan activas'
);

select is_empty(
  $$
    with esperado(subcategoria_slug, categoria_slug) as (
      values
        ('centros-comerciales-grandes-almacenes', 'tiendas-supermercados'),
        ('venta-vehiculos', 'automotriz-movilidad'),
        ('jugueterias', 'educacion-papeleria'),
        ('floristerias', 'tiendas-supermercados')
    )
    select e.subcategoria_slug
    from esperado e
    left join public.subcategorias s on s.slug = e.subcategoria_slug
    left join public.categorias c on c.id = s.categoria_id
    where s.id is null or c.slug <> e.categoria_slug
  $$,
  'cada subcategoria nueva pertenece a la categoria oficial correcta'
);

select * from finish();

rollback;
