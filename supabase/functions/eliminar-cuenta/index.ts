import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import { createNormalDeletionHandler } from '../_shared/account_deletion_handler.mjs';

Deno.serve(createNormalDeletionHandler(createClient, {
  url: Deno.env.get('SUPABASE_URL'),
  anonKey: Deno.env.get('SUPABASE_ANON_KEY'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  allowedOrigins: Deno.env.get('CERCLY_ACCOUNT_DELETION_ALLOWED_ORIGINS') ?? '',
}));
