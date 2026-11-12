import { NextResponse } from "next/server";
import { appUrl } from "@/lib/notify";
import { getServerUser } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function icsDate(d: Date): string {
  return d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function esc(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/;/g, "\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
}

/** Fichier .ics d'un rendez-vous (ouvre l'ajout au calendrier sur iPhone/Android/desktop). */
export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const { supabase, user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });

  const { data } = await supabase
    .from("rendezvous")
    .select("id, title, location, notes, appointment_at, contact_rendezvous(contacts(name))")
    .eq("id", id)
    .maybeSingle();
  if (!data) return NextResponse.json({ error: "Introuvable" }, { status: 404 });

  const rdv = data as unknown as {
    id: string;
    title: string | null;
    location: string | null;
    notes: string | null;
    appointment_at: string;
    contact_rendezvous: { contacts: { name: string } | null }[] | null;
  };
  const names = (rdv.contact_rendezvous ?? []).map((x) => x.contacts?.name ?? "").filter(Boolean);
  const start = new Date(rdv.appointment_at);
  const end = new Date(start.getTime() + 60 * 60 * 1000);
  const summary = rdv.title || (names.length ? `Rendez-vous avec ${names.join(", ")}` : "Rendez-vous SeeYourB");
  const description = [names.length ? `Avec : ${names.join(", ")}` : null, rdv.notes].filter(Boolean).join("\n");

  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//SeeYourB//FR",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:${rdv.id}@seeyourb`,
    `DTSTAMP:${icsDate(new Date())}`,
    `DTSTART:${icsDate(start)}`,
    `DTEND:${icsDate(end)}`,
    `SUMMARY:${esc(summary)}`,
    description ? `DESCRIPTION:${esc(description)}` : null,
    rdv.location ? `LOCATION:${esc(rdv.location)}` : null,
    `URL:${appUrl(`/rdv/${rdv.id}`)}`,
    "BEGIN:VALARM",
    "TRIGGER:-PT30M",
    "ACTION:DISPLAY",
    "DESCRIPTION:Rappel SeeYourB",
    "END:VALARM",
    "END:VEVENT",
    "END:VCALENDAR",
  ].filter(Boolean);

  return new NextResponse(lines.join("\r\n") + "\r\n", {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": `attachment; filename="seeyourb-${rdv.id.slice(0, 8)}.ics"`,
      "Cache-Control": "no-store",
    },
  });
}
