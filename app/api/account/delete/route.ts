import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { getServerUser } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Supprime définitivement le compte connecté : fichiers, données (cascade) et utilisateur Auth. */
export async function POST() {
  const { user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });

  try {
    const admin = createAdminClient();

    // 1) Fichiers du dossier privé de l'utilisateur
    const bucket = admin.storage.from("photos");
    for (let i = 0; i < 20; i++) {
      const { data: files } = await bucket.list(user.id, { limit: 1000 });
      if (!files?.length) break;
      await bucket.remove(files.map((f) => `${user.id}/${f.name}`));
      if (files.length < 1000) break;
    }

    // 2) Utilisateur Auth (les tables ont "on delete cascade")
    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });

    return NextResponse.json({ ok: true });
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Erreur serveur" }, { status: 500 });
  }
}
