// Solo harness local: mismo handler y versión de SDK que el entrypoint real.
// Sin gateway Edge, correo externo, sustitutos ni acceso a proyectos alojados.
import { createClient } from 'npm:@supabase/supabase-js@2.75.0';
import { createNormalDeletionHandler } from '../supabase/functions/_shared/account_deletion_handler.mjs';

const url = Deno.env.get('SUPABASE_URL');
if (url !== 'http://127.0.0.1:56431') {
  throw new Error('Este arnés solo acepta el stack local desechable');
}
Deno.serve({ hostname: '127.0.0.1', port: 56435 }, createNormalDeletionHandler(createClient, {
  url,
  anonKey: Deno.env.get('SUPABASE_ANON_KEY'),
  serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  allowedOrigins: '',
}));
