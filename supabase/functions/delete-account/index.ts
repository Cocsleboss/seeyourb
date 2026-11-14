// SeeU — permanently deletes the calling user's account:
// their files in the private "photos" bucket, then the Auth user
// (every table references auth.users with ON DELETE CASCADE).

import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userError || !user) return json({ error: "Non connecté" }, 401);

  try {
    const bucket = admin.storage.from("photos");
    for (let i = 0; i < 50; i++) {
      const { data: files, error } = await bucket.list(user.id, { limit: 1000 });
      if (error) throw error;
      if (!files?.length) break;
      await bucket.remove(files.map((f) => `${user.id}/${f.name}`));
      if (files.length < 1000) break;
    }

    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : "Erreur serveur" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "content-type": "application/json" } });
}
