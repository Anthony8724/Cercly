// Exclusivo del ensayo STAGING; no seleccionar esta ruta desde el cliente normal.
import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import { createQaDeletionHandler } from '../_shared/account_deletion_handler.mjs';

Deno.serve(createQaDeletionHandler(createClient, {
  url: Deno.env.get('SUPABASE_URL'),
  anonKey: Deno.env.get('SUPABASE_ANON_KEY'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  allowedOrigins: Deno.env.get('CERCLY_QA_ACCOUNT_DELETION_ALLOWED_ORIGINS') ?? '',
}));
