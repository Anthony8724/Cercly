-- SOLO LECTURA. Ejecutar únicamente por un operador autorizado en un entorno
-- aprobado; el resultado contiene UUID y debe tratarse como información sensible.
begin transaction read only;

select 'auth_usuarios' as entidad, count(*) as registros from auth.users
union all select 'perfiles', count(*) from public.usuarios
union all select 'administradores', count(*) from public.usuarios where rol='administrador'
union all select 'propietarios', count(*) from public.usuarios where rol='propietario'
union all select 'establecimientos', count(*) from public.establecimientos
union all select 'promociones', count(*) from public.promociones
union all select 'solicitudes', count(*) from public.solicitudes_establecimientos
union all select 'fotos', count(*) from public.fotos_establecimiento
union all select 'objetos_storage', count(*) from storage.objects
union all select 'categorias_estructurales', count(*) from public.categorias
union all select 'subcategorias_estructurales', count(*) from public.subcategorias;

-- Ningún registro se declara ficticio por correo, fecha o rol.
select a.id as auth_uuid, u.rol::text as rol,
  (select count(*) from public.establecimientos e where e.propietario_id=a.id) as negocios_propios,
  (select count(*) from public.miembros_establecimiento m where m.usuario_id=a.id and m.activo) as membresias_activas,
  (select count(*) from public.solicitudes_establecimientos s where s.solicitante_id=a.id) as solicitudes,
  (select count(*) from storage.objects o where o.owner_id=a.id::text) as objetos_storage,
  case when u.id is null then 'perfil_ausente: revision_manual'
       else 'revision_manual' end as clasificacion_inicial
from auth.users a left join public.usuarios u on u.id=a.id
order by a.id;

select e.id as establecimiento_id, e.propietario_id, e.estado::text,
  (select count(*) from public.miembros_establecimiento m where m.establecimiento_id=e.id and m.activo) as miembros,
  (select count(*) from public.promociones p where p.establecimiento_id=e.id) as promociones,
  (select count(*) from public.fotos_establecimiento f where f.establecimiento_id=e.id) as fotos,
  (select count(*) from public.solicitudes_establecimientos s where s.establecimiento_id=e.id) as solicitudes
from public.establecimientos e order by e.id;

select bucket_id, owner_id, count(*) as objetos
from storage.objects group by bucket_id, owner_id order by bucket_id, owner_id;

select n.nspname as esquema, t.relname as tabla, c.conname as clave_foranea,
  c.confrelid::regclass as tabla_referenciada, pg_get_constraintdef(c.oid) as definicion
from pg_constraint c join pg_class t on t.oid=c.conrelid
  join pg_namespace n on n.oid=t.relnamespace
where c.contype='f' and n.nspname in ('public','auth','storage','cercly_auth_private','cercly_account_private')
order by n.nspname,t.relname,c.conname;

commit;
