-- Preparada para revisión y prueba aislada. NO aplicada remotamente.
-- La cuota solo conserva datos propios y se borra por cascada de Auth.
-- Reconocer exclusivamente la FK exacta; otras FK siguen bloqueando supresión.
-- CREATE OR REPLACE preserva propietario y ACL de la función existente.
begin;
create or replace function cercly_account_private.es_referencia_identidad_plataforma(p_constraint oid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists (
  select 1 from pg_catalog.pg_constraint c
  join pg_catalog.pg_class t on t.oid=c.conrelid
  join pg_catalog.pg_namespace n on n.oid=t.relnamespace
  join (values
    ('auth','identities','identities_user_id_fkey','user_id','c'),
    ('auth','mfa_factors','mfa_factors_user_id_fkey','user_id','c'),
    ('auth','mfa_recovery_code_sets','mfa_recovery_code_sets_user_id_fkey','user_id','c'),
    ('auth','oauth_authorizations','oauth_authorizations_user_id_fkey','user_id','c'),
    ('auth','oauth_consents','oauth_consents_user_id_fkey','user_id','c'),
    ('auth','one_time_tokens','one_time_tokens_user_id_fkey','user_id','c'),
    ('auth','scim_users','scim_users_user_id_fkey','user_id','n'),
    ('auth','sessions','sessions_user_id_fkey','user_id','c'),
    ('auth','webauthn_challenges','webauthn_challenges_user_id_fkey','user_id','c'),
    ('auth','webauthn_credentials','webauthn_credentials_user_id_fkey','user_id','c'),
    ('cercly_account_private','planes_supresion','planes_supresion_revisor_id_fkey','revisor_id','c'),
    ('cercly_account_private','planes_supresion','planes_supresion_sujeto_id_fkey','sujeto_id','c'),
    ('cercly_account_private','sujetos_qa_supresion','sujetos_qa_supresion_usuario_id_fkey','usuario_id','c'),
    ('cercly_rutas_privado','rutas_limites_usuarios','rutas_limites_usuarios_usuario_id_fkey','usuario_id','c')
  ) known(schema_name,table_name,constraint_name,column_name,delete_action)
   on n.nspname=known.schema_name and t.relname=known.table_name and c.conname=known.constraint_name
  where c.oid=p_constraint and c.contype='f' and c.convalidated
   and c.confrelid='auth.users'::regclass and c.confdeltype::text=known.delete_action
   and c.conkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
     where a.attrelid=c.conrelid and a.attname=known.column_name and not a.attisdropped)]
   and c.confkey=array[(select a.attnum::smallint from pg_catalog.pg_attribute a
     where a.attrelid=c.confrelid and a.attname='id' and not a.attisdropped)]
 );
$$;
commit;
