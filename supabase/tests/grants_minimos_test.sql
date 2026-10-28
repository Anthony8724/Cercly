begin;
select plan(4);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'),
                       ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')) p(privilege)
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and has_table_privilege('anon', c.oid, p.privilege)
  ),
  'anon has no table DML or elevated table privileges'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    cross join (values ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')) p(privilege)
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and has_table_privilege('authenticated', c.oid, p.privilege)
  ),
  'authenticated has no elevated table privileges'
);

select ok(
  has_table_privilege('anon', 'public.categorias', 'SELECT'),
  'anonymous public category reads remain available'
);

select ok(
  has_table_privilege('authenticated', 'public.establecimientos', 'INSERT')
    and has_table_privilege('authenticated', 'public.establecimientos', 'UPDATE')
    and has_table_privilege('authenticated', 'public.establecimientos', 'DELETE'),
  'authenticated CRUD remains available subject to RLS policies'
);

select * from finish();
rollback;
