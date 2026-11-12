import { NextResponse } from "next/server";
import { notifyUser } from "@/lib/notify";
import { createAdminClient } from "@/lib/supabase/admin";
import { getServerUser } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Envoie une notification de test à l'utilisateur connecté (push, sinon email). */
export async function POST() {
  const { user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });
  try {
    const admin = createAdminClient();
    const result = await notifyUser(
      admin,
      user.id,
      {
        kind: "test",
        title: "SeeYourB fonctionne ✅",
        body: "Vous recevrez ici vos rappels de contacts et de rendez-vous.",
        url: "/settings",
        tag: "test",
      },
      { forcePush: true }
    );
    return NextResponse.json(result);
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Erreur serveur" }, { status: 500 });
  }
}
