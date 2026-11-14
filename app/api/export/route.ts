import { NextResponse } from "next/server";
import { getServerUser } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

/** Export JSON de toutes les données de l'utilisateur connecté (RLS). */
export async function GET() {
  const { supabase, user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });

  const [profile, contacts, rendezvous, links, photos] = await Promise.all([
    supabase.from("profiles").select("*").maybeSingle(),
    supabase.from("contacts").select("*").order("name"),
    supabase.from("rendezvous").select("*").order("appointment_at"),
    supabase.from("contact_rendezvous").select("contact_id, rendezvous_id"),
    supabase.from("photos").select("*"),
  ]);

  const payload = {
    exported_at: new Date().toISOString(),
    app: "SeeU",
    user: { id: user.id, email: user.email },
    profile: profile.data,
    contacts: contacts.data ?? [],
    rendezvous: rendezvous.data ?? [],
    contact_rendezvous: links.data ?? [],
    photos: photos.data ?? [],
  };

  return new NextResponse(JSON.stringify(payload, null, 2), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition": `attachment; filename="seeu-export-${new Date().toISOString().slice(0, 10)}.json"`,
      "Cache-Control": "no-store",
    },
  });
}
