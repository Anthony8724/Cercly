-- Solo contenedor aislado: compatibilidad mínima de plataforma, no producción.
-- Misma resolución de identidad observada en la copia: claims JSON de PostgREST
-- y claim individual legacy. No concede lectura sobre tablas Auth a clientes.
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid;
$$;
alter table auth.users add column if not exists phone text;
alter table auth.users add column if not exists email_confirmed_at timestamptz;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
alter table storage.objects enable row level security;
create function storage.foldername(text) returns text[] language sql immutable as $$ select (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1] $$;
grant usage on schema storage,auth,public,extensions to anon,authenticated;
grant all on storage.objects to anon,authenticated;
create extension pgtap with schema extensions;
grant all on storage.buckets,storage.objects to postgres;
