-- Solo contenedor aislado: compatibilidad mínima de plataforma, no producción.
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
