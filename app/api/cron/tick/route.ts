/**
 * Tâche planifiée (appelée toutes les 10 min par pg_cron, cron-job.org ou Vercel Cron) :
 *   1. rappels avant rendez-vous (selon la préférence de chaque utilisateur, 30 min par défaut),
 *   2. suivi "ce rendez-vous a-t-il eu lieu ?" quelques heures après un rendez-vous planifié non confirmé,
 *   3. digest quotidien des contacts à recontacter (+ anniversaires), à l'heure choisie par l'utilisateur.
 * Chaque envoi est "réclamé" en base avant l'envoi (flags), donc jamais de doublon même si deux ticks se chevauchent.
 */
import { NextResponse } from "next/server";
import { isCronAuthorized, notifyUser } from "@/lib/notify";
import { createAdminClient } from "@/lib/supabase/admin";
import type { Profile } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;

const FALLBACK_TZ = "Europe/Paris";

function localParts(date: Date, tz: string): { date: string; hour: number; monthDay: string } {
  const compute = (zone: string) => {
    const fmt = new Intl.DateTimeFormat("en-CA", {
      timeZone: zone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      hour12: false,
    });
    const parts: Record<string, string> = {};
    fmt.formatToParts(date).forEach((p) => (parts[p.type] = p.value));
    const hour = parseInt(parts.hour, 10) % 24;
    return { date: `${parts.year}-${parts.month}-${parts.day}`, hour, monthDay: `${parts.month}-${parts.day}` };
  };
  try {
    return compute(tz);
  } catch {
    return compute("UTC");
  }
}

function fmtTime(date: Date, tz: string): string {
  try {
    return new Intl.DateTimeFormat("fr-FR", { timeZone: tz, hour: "2-digit", minute: "2-digit" }).format(date);
  } catch {
    return new Intl.DateTimeFormat("fr-FR", { timeZone: "UTC", hour: "2-digit", minute: "2-digit" }).format(date);
  }
}

function fmtDay(date: Date, tz: string): string {
  try {
    return new Intl.DateTimeFormat("fr-FR", { timeZone: tz, weekday: "long", day: "numeric", month: "long" }).format(date);
  } catch {
    return new Intl.DateTimeFormat("fr-FR", { timeZone: "UTC", weekday: "long", day: "numeric", month: "long" }).format(date);
  }
}

function addDaysISO(iso: string, n: number): string {
  const d = new Date(iso + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function diffDays(fromISO: string, toISO: string): number {
  return Math.round((Date.parse(toISO + "T00:00:00Z") - Date.parse(fromISO + "T00:00:00Z")) / 86400000);
}

function joinNames(names: string[], max = 3): string {
  const list = names.filter(Boolean);
  if (!list.length) return "";
  if (list.length === 1) return list[0];
  if (list.length <= max) return `${list.slice(0, -1).join(", ")} et ${list[list.length - 1]}`;
  const rest = list.length - max;
  return `${list.slice(0, max).join(", ")} et ${rest} autre${rest > 1 ? "s" : ""}`;
}

function dueLabel(dueISO: string, todayISO: string): string {
  const d = diffDays(todayISO, dueISO);
  if (d < 0) return `en retard de ${-d} j`;
  if (d === 0) return "aujourd'hui";
  return `dans ${d} j`;
}

interface RdvRow {
  id: string;
  user_id: string;
  title: string | null;
  location: string | null;
  appointment_at: string;
  contact_rendezvous: { contacts: { name: string } | null }[] | null;
}

interface ContactRow {
  id: string;
  name: string;
  next_due_date: string;
  snooze_until: string | null;
  birthday: string | null;
  notified_current_cycle: boolean;
}

const effectiveDue = (c: ContactRow) =>
  c.snooze_until && c.snooze_until > c.next_due_date ? c.snooze_until : c.next_due_date;

async function handle(req: Request) {
  if (!isCronAuthorized(req)) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const admin = createAdminClient();
  const now = new Date();
  const summary = { rdvReminders: 0, followups: 0, digests: 0, birthdays: 0, errors: [] as string[] };

  const { data: profileRows, error: pErr } = await admin.from("profiles").select("*");
  if (pErr) return NextResponse.json({ error: pErr.message }, { status: 500 });
  const profiles = new Map<string, Profile>();
  (profileRows as Profile[] | null)?.forEach((p) => profiles.set(p.id, p));

  /* ---------------- 1) Rappels avant rendez-vous ---------------- */
  try {
    const windowStart = new Date(now.getTime() - 15 * 60_000).toISOString();
    const windowEnd = new Date(now.getTime() + 25 * 3_600_000).toISOString();
    const { data, error } = await admin
      .from("rendezvous")
      .select("id, user_id, title, location, appointment_at, contact_rendezvous(contacts(name))")
      .eq("status", "planifie")
      .eq("reminder_sent", false)
      .gte("appointment_at", windowStart)
      .lte("appointment_at", windowEnd);
    if (error) throw error;
    for (const r of (data ?? []) as unknown as RdvRow[]) {
      const profile = profiles.get(r.user_id) ?? null;
      const lead = profile?.rdv_reminder_minutes ?? 30;
      const at = new Date(r.appointment_at);
      const minutesUntil = (at.getTime() - now.getTime()) / 60_000;
      if (minutesUntil > lead + 5) continue;

      const { data: claimed } = await admin
        .from("rendezvous")
        .update({ reminder_sent: true })
        .eq("id", r.id)
        .eq("reminder_sent", false)
        .select("id");
      if (!claimed?.length) continue;

      const tz = profile?.timezone || FALLBACK_TZ;
      const names = (r.contact_rendezvous ?? []).map((x) => x.contacts?.name ?? "").filter(Boolean);
      const when =
        minutesUntil <= 1 ? "maintenant" : minutesUntil < 90 ? `dans ${Math.round(minutesUntil)} min` : `à ${fmtTime(at, tz)}`;
      const title = names.length ? `Rendez-vous avec ${joinNames(names)} ${when}` : `Rendez-vous ${when}`;
      const body = [r.title, `${fmtDay(at, tz)} à ${fmtTime(at, tz)}`, r.location ? `📍 ${r.location}` : null]
        .filter(Boolean)
        .join(" · ");
      await notifyUser(admin, r.user_id, { kind: "rdv_reminder", title, body, url: `/rdv/${r.id}`, tag: `rdv-${r.id}` }, { profile });
      summary.rdvReminders++;
    }
  } catch (e) {
    summary.errors.push("reminders: " + (e instanceof Error ? e.message : String(e)));
  }

  /* ---------------- 2) Suivi après rendez-vous ---------------- */
  try {
    const start = new Date(now.getTime() - 26 * 3_600_000).toISOString();
    const end = new Date(now.getTime() - 2 * 3_600_000).toISOString();
    const { data, error } = await admin
      .from("rendezvous")
      .select("id, user_id, title, location, appointment_at, contact_rendezvous(contacts(name))")
      .eq("status", "planifie")
      .eq("followup_sent", false)
      .gte("appointment_at", start)
      .lte("appointment_at", end);
    if (error) throw error;
    for (const r of (data ?? []) as unknown as RdvRow[]) {
      const profile = profiles.get(r.user_id) ?? null;
      const { data: claimed } = await admin
        .from("rendezvous")
        .update({ followup_sent: true })
        .eq("id", r.id)
        .eq("followup_sent", false)
        .select("id");
      if (!claimed?.length) continue;
      const names = (r.contact_rendezvous ?? []).map((x) => x.contacts?.name ?? "").filter(Boolean);
      const title = names.length
        ? `Votre rendez-vous avec ${joinNames(names)} a-t-il eu lieu ?`
        : "Votre rendez-vous a-t-il eu lieu ?";
      const body = "Confirmez-le pour mettre à jour la date de dernière rencontre, ou marquez-le comme annulé.";
      await notifyUser(admin, r.user_id, { kind: "rdv_followup", title, body, url: `/rdv/${r.id}`, tag: `rdv-${r.id}` }, { profile });
      summary.followups++;
    }
  } catch (e) {
    summary.errors.push("followups: " + (e instanceof Error ? e.message : String(e)));
  }

  /* ---------------- 3) Digest quotidien + anniversaires ---------------- */
  for (const profile of profiles.values()) {
    try {
      const tz = profile.timezone || FALLBACK_TZ;
      const { date: localDate, hour, monthDay } = localParts(now, tz);
      if (hour < (profile.daily_hour ?? 8)) continue;
      if (profile.last_digest_date && profile.last_digest_date >= localDate) continue;

      // Réserve la journée (évite un double envoi si deux ticks se chevauchent)
      const { data: claimed } = await admin
        .from("profiles")
        .update({ last_digest_date: localDate })
        .eq("id", profile.id)
        .or(`last_digest_date.is.null,last_digest_date.lt.${localDate}`)
        .select("id");
      if (!claimed?.length) continue;

      const { data: rows, error } = await admin
        .from("contacts")
        .select("id, name, next_due_date, snooze_until, birthday, notified_current_cycle")
        .eq("user_id", profile.id);
      if (error) throw error;
      const contacts = (rows ?? []) as ContactRow[];
      const horizon = addDaysISO(localDate, profile.due_lead_days ?? 0);

      const due = contacts
        .filter((c) => !c.notified_current_cycle && effectiveDue(c) <= horizon)
        .sort((a, b) => (effectiveDue(a) < effectiveDue(b) ? -1 : 1));
      if (due.length) {
        const overdueTotal = contacts.filter((c) => effectiveDue(c) < localDate).length;
        const title = due.length === 1 ? `${due[0].name} est à recontacter` : `${due.length} contacts à recontacter`;
        const parts = due.slice(0, 5).map((c) => `${c.name} (${dueLabel(effectiveDue(c), localDate)})`);
        let body = parts.join(", ");
        if (due.length > 5) body += ` et ${due.length - 5} autre${due.length - 5 > 1 ? "s" : ""}`;
        if (overdueTotal > due.length) body += ` · ${overdueTotal} en retard au total`;
        await notifyUser(admin, profile.id, { kind: "due_digest", title, body, url: "/", tag: "due-digest" }, { profile });
        await admin
          .from("contacts")
          .update({ notified_current_cycle: true })
          .in(
            "id",
            due.map((c) => c.id)
          );
        summary.digests++;
      }

      const isLeap = (y: number) => (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
      const year = parseInt(localDate.slice(0, 4), 10);
      const bdays = contacts.filter((c) => {
        if (!c.birthday) return false;
        const md = c.birthday.slice(5);
        if (md === monthDay) return true;
        return md === "02-29" && monthDay === "02-28" && !isLeap(year);
      });
      if (bdays.length) {
        const names = bdays.map((c) => c.name);
        const title = bdays.length === 1 ? `🎂 C'est l'anniversaire de ${names[0]} !` : `🎂 ${bdays.length} anniversaires aujourd'hui`;
        const body = bdays.length === 1 ? "Un petit message lui fera plaisir." : joinNames(names, 4);
        await notifyUser(admin, profile.id, { kind: "birthday", title, body, url: "/contacts", tag: "birthday" }, { profile });
        summary.birthdays++;
      }
    } catch (e) {
      summary.errors.push(`digest ${profile.id}: ` + (e instanceof Error ? e.message : String(e)));
    }
  }

  return NextResponse.json({ ok: true, at: now.toISOString(), ...summary });
}

export async function GET(req: Request) {
  return handle(req);
}

export async function POST(req: Request) {
  return handle(req);
}
