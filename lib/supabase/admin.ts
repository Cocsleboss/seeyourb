import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * Client "service role" : contourne la RLS. À n'utiliser QUE côté serveur
 * (cron, envoi de notifications, suppression de compte). Jamais exposé au client.
 */
export function createAdminClient(): SupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY ou NEXT_PUBLIC_SUPABASE_URL manquante");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
}
