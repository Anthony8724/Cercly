-- Exclusivamente para una base local QA vacia.
-- Los datos de prueba se revierten al finalizar.

begin;

do $$
begin
  if exists (select 1 from auth.users)
     or exists (select 1 from public.usuarios) then
    raise exception 'QA debe estar vacia de usuarios';
  end if;
end;
$$;

-- Crear 209 cuentas sinteticas.
insert into auth.users (
  id,
  aud,
  role,
  email,
  raw_user_meta_data,
  created_at,
  last_sign_in_at
)
select
  md5('estadisticas-qa-' || i)::uuid,
  'authenticated',
  'authenticated',
  'estadisticas-' || i || '@cercly.test',
  jsonb_build_object(
    'nombre', 'Usuario QA',
    'rol', case when i = 3
                then 'administrador'
                else 'usuario' end
  ),
  now() - interval '60 days',
  case
    when i = 3 then null
    when i = 4 then now() - interval '45 days'
    else now() - interval '1 day'
  end
from generate_series(1, 209) as g(i);

update public.usuarios
set rol = 'administrador'
where id = md5('estadisticas-qa-1')::uuid;

update public.usuarios
set rol = 'propietario'
where id = md5('estadisticas-qa-2')::uuid;

-- Verificar que los metadatos no conceden privilegios.
do $$
begin
  if (select rol::text from public.usuarios
      where id = md5('estadisticas-qa-3')::uuid)
      is distinct from 'usuario' then
    raise exception 'Elevacion indebida de privilegios';
  end if;

  raise notice 'APROBADO: metadatos no elevan privilegios';
end;
$$;

-- Probar acceso anonimo.
set local role anon;

do $$
declare
  consulta text;
begin
  foreach consulta in array array[
    'select public.admin_estadisticas_resumen(30)',
    'select * from public.admin_estadisticas_registros(current_date,current_date,''dia'')',
    'select * from public.admin_usuarios_activos_detalle(30,200,0)'
  ]
  loop
    begin
      execute consulta;
      raise exception 'Acceso anonimo indebido: %', consulta;
    exception
      when insufficient_privilege then null;
    end;
  end loop;

  raise notice 'APROBADO: acceso anonimo rechazado';
end;
$$;

reset role;

-- Probar propietario, usuario normal y ausencia de identidad.
set local role authenticated;

do $$
declare
  sujeto text;
  consulta text;
begin
  foreach sujeto in array array[
    md5('estadisticas-qa-2')::uuid::text,
    md5('estadisticas-qa-3')::uuid::text,
    ''
  ]
  loop
    perform set_config(
      'request.jwt.claim.sub', sujeto, true
    );

    foreach consulta in array array[
      'select public.admin_estadisticas_resumen(30)',
      'select * from public.admin_estadisticas_registros(current_date,current_date,''dia'')',
      'select * from public.admin_usuarios_activos_detalle(30,200,0)'
    ]
    loop
      begin
        execute consulta;
        raise exception 'Acceso administrativo indebido';
      exception
        when insufficient_privilege then null;
      end;
    end loop;

    raise notice 'APROBADO: identidad no administrativa rechazada';
  end loop;
end;
$$;

reset role;

-- Probar administrador autorizado.
set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  md5('estadisticas-qa-1')::uuid::text,
  true
);

do $$
declare
  resumen jsonb;
  pagina1 uuid[];
  pagina2 uuid[];
  esperado uuid[];
begin
  if public.es_administrador() is not true then
    raise exception 'Administrador no reconocido';
  end if;

  resumen := public.admin_estadisticas_resumen(30);

  if (resumen->>'usuarios_total')::integer
      is distinct from 209 then
    raise exception 'Total de usuarios incorrecto';
  end if;

  if (resumen->>'propietarios_total')::integer
      is distinct from 1 then
    raise exception 'Total de propietarios incorrecto';
  end if;

  if (resumen->>'administradores_total')::integer
      is distinct from 1 then
    raise exception 'Total de administradores incorrecto';
  end if;

  if (resumen->>'usuarios_normales_total')::integer
      is distinct from 207 then
    raise exception 'Total de usuarios normales incorrecto';
  end if;

  if (resumen->>'usuarios_activos')::integer
      is distinct from 207 then
    raise exception 'Total de usuarios activos incorrecto';
  end if;

  raise notice 'APROBADO: resumen de usuarios correcto';

  select array_agg(id order by ordinality)
  into pagina1
  from public.admin_usuarios_activos_detalle(30,200,0)
  with ordinality;

  select array_agg(id order by ordinality)
  into pagina2
  from public.admin_usuarios_activos_detalle(30,200,200)
  with ordinality;

  if cardinality(pagina1) is distinct from 200
     or cardinality(pagina2) is distinct from 7 then
    raise exception 'Paginacion incorrecta';
  end if;

  if pagina1 && pagina2 then
    raise exception 'Usuarios duplicados entre paginas';
  end if;

  select array_agg(
    md5('estadisticas-qa-' || i)::uuid
    order by md5('estadisticas-qa-' || i)::uuid
  )
  into esperado
  from generate_series(1,209) as g(i)
  where i not in (3,4);

  if (pagina1 || pagina2) is distinct from esperado then
    raise exception 'Orden o conjunto de usuarios incorrecto';
  end if;

  if exists (
    select 1
    from public.admin_usuarios_activos_detalle(30,200,400)
  ) then
    raise exception 'La pagina final deberia estar vacia';
  end if;

  raise notice 'APROBADO: paginacion 200 + 7 sin duplicados';
  raise notice 'APROBADO: orden determinista';
  raise notice 'APROBADO: usuarios sin acceso reciente excluidos';
end;
$$;

-- Probar parametros invalidos.
do $$
declare
  consulta text;
begin
  foreach consulta in array array[
    'select * from public.admin_usuarios_activos_detalle(0,200,0)',
    'select * from public.admin_usuarios_activos_detalle(366,200,0)',
    'select * from public.admin_usuarios_activos_detalle(30,0,0)',
    'select * from public.admin_usuarios_activos_detalle(30,201,0)',
    'select * from public.admin_usuarios_activos_detalle(30,200,-1)',
    'select * from public.admin_usuarios_activos_detalle(null,200,0)',
    'select * from public.admin_usuarios_activos_detalle(30,null,0)',
    'select * from public.admin_usuarios_activos_detalle(30,200,null)'
  ]
  loop
    begin
      execute consulta;
      raise exception 'Parametro invalido aceptado: %', consulta;
    exception
      when invalid_parameter_value then null;
    end;
  end loop;

  raise notice 'APROBADO: ocho parametros invalidos rechazados';
end;
$$;

-- Comprobar visibilidad administrativa mediante RLS.
do $$
declare
  desde date;
  hasta date;
  granularidad text;
  normales bigint;
  propietarios bigint;
begin
  if (select count(*) from public.usuarios) <> 209 then
    raise exception 'RLS limita indebidamente al administrador';
  end if;

  raise notice 'APROBADO: administrador consulta todos los perfiles';

  select
    min((creado_en at time zone 'America/Guayaquil')::date),
    max((creado_en at time zone 'America/Guayaquil')::date)
  into desde, hasta
  from public.usuarios;

  foreach granularidad in array array['dia','semana','mes']
  loop
    select
      coalesce(sum(total) filter (
        where tipo_usuario = 'usuario'
      ), 0),
      coalesce(sum(total) filter (
        where tipo_usuario = 'propietario'
      ), 0)
    into normales, propietarios
    from public.admin_estadisticas_registros(
      desde, hasta, granularidad
    );

    if normales <> 207 or propietarios <> 1 then
      raise exception 'Registros incorrectos: %', granularidad;
    end if;

    if exists (
      select 1
      from public.admin_estadisticas_registros(
        desde, hasta, granularidad
      )
      where tipo_usuario not in ('usuario','propietario')
    ) then
      raise exception 'Rol indebido en la serie de registros';
    end if;

    raise notice 'APROBADO: registros por %', granularidad;
  end loop;
end;
$$;

-- Comprobar aislamiento de perfiles para usuarios no administradores.
do $$
declare
  sujeto uuid;
begin
  foreach sujeto in array array[
    md5('estadisticas-qa-2')::uuid,
    md5('estadisticas-qa-3')::uuid
  ]
  loop
    perform set_config(
      'request.jwt.claim.sub', sujeto::text, true
    );

    if (select count(*) from public.usuarios) <> 1
       or not exists (
         select 1 from public.usuarios where id = sujeto
       ) then
      raise exception 'RLS no aisla correctamente los perfiles';
    end if;

    raise notice 'APROBADO: perfil privado aislado mediante RLS';
  end loop;
end;
$$;

reset role;

rollback;

select 'TODAS LAS COMPROBACIONES SQL APROBADAS' as resultado;
