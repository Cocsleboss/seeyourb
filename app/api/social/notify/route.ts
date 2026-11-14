import { NextResponse } from "next/server";
import { notifyUser, type NotifyPayload } from "@/lib/notify";
import { createAdminClient } from "@/lib/supabase/admin";
import { getServerUser } from "@/lib/supabase/server";
import type { Profile } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type Kind = "friend_request" | "friend_accept" | "rdv_invite" | "rdv_response" | "rdv_change" | "wave";
const KINDS: Kind[] = ["friend_request", "friend_accept", "rdv_invite", "rdv_response", "rdv_change", "wave"];

function nameOf(p: Profile | null): string {
  return p?.display_name?.trim() || p?.email?.split("@")[0] || "Un ami";
}

function whenLabel(iso: string, tz: string | null | undefined): string {
  const opts: Intl.DateTimeFormatOptions = { weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit" };
  try {
    return new Intl.DateTimeFormat("fr-FR", { ...opts, timeZone: tz || "Europe/Paris" }).format(new Date(iso));
  } catch {
    return new Intl.DateTimeFormat("fr-FR", { ...opts, timeZone: "Europe/Paris" }).format(new Date(iso));
  }
}

/**
 * Prévient l'autre personne après une action sociale (demande d'ami, invitation à un rendez-vous, réponse,
 * rendez-vous partagé validé / annulé / déplacé, « envie de se voir »).
 * L'action elle-même est déjà faite en base (fonctions SQL) : ici on vérifie seulement que l'appelant
 * en est bien l'auteur, puis on envoie la notification (push, sinon email) au destinataire.
 */
export async function POST(req: Request) {
  const { user } = await getServerUser();
  if (!user) return NextResponse.json({ error: "Non connecté" }, { status: 401 });

  let body: { type?: string; id?: string; change?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Requête invalide" }, { status: 400 });
  }
  const type = body.type as Kind;
  const id = body.id;
  if (!KINDS.includes(type) || typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) {
    return NextResponse.json({ error: "Requête invalide" }, { status: 400 });
  }

  try {
    const admin = createAdminClient();
    const profileOf = async (uid: string) =>
      ((await admin.from("profiles").select("*").eq("id", uid).maybeSingle()).data as Profile | null) ?? null;
    const me = await profileOf(user.id);

    let target: string | null = null;
    let payload: NotifyPayload | null = null;

    if (type === "friend_request" || type === "friend_accept") {
      const { data: f } = await admin.from("friendships").select("*").eq("id", id).maybeSingle();
      if (!f) return NextResponse.json({ ok: false });
      if (type === "friend_request" && f.requester_id === user.id && f.status === "pending") {
        target = f.addressee_id;
        payload = {
          kind: "friend_request",
          title: `${nameOf(me)}${me?.username ? ` (@${me.username})` : ""} vous a ajouté sur SeeU`,
          body: "Acceptez sa demande pour partager vos rendez-vous et vos photos.",
          url: "/friends",
          tag: `friend-${id}`,
        };
      } else if (type === "friend_accept" && f.status === "accepted" && [f.requester_id, f.addressee_id].includes(user.id)) {
        target = f.requester_id === user.id ? f.addressee_id : f.requester_id;
        payload = {
          kind: "friend_accept",
          title: `${nameOf(me)} a accepté votre demande`,
          body: "Vous pouvez maintenant lui proposer des rendez-vous.",
          url: "/friends",
          tag: `friend-${id}`,
        };
      }
    } else if (type === "wave") {
      // « Envie de se voir » : le signe doit venir de l'appelant et être tout récent (pas de renvoi)
      const { data: w } = await admin.from("waves").select("*").eq("id", id).maybeSingle();
      if (!w || w.from_user !== user.id || Date.now() - new Date(w.created_at).getTime() > 10 * 60 * 1000) {
        return NextResponse.json({ ok: false });
      }
      const { data: c } = await admin.from("contacts").select("id").eq("user_id", w.to_user).eq("linked_user_id", user.id).maybeSingle();
      target = w.to_user;
      payload = {
        kind: "wave",
        title: `👋 ${nameOf(me)} aimerait vous voir`,
        body: c ? "Proposez un rendez-vous : ce contact est en tête de votre liste « À voir bientôt »." : "Proposez un rendez-vous dans SeeU.",
        url: c ? `/contacts/${c.id}` : "/friends",
        tag: `wave-${user.id}`,
      };
    } else if (type === "rdv_change") {
      // Un rendez-vous partagé vient d'être validé, annulé, replanifié ou déplacé par l'appelant :
      // on prévient les amis qui en ont une copie (leur copie a déjà été mise à jour en base).
      const { data: rdv } = await admin.from("rendezvous").select("id, user_id, share_id, title, status, appointment_at").eq("id", id).maybeSingle();
      if (!rdv || rdv.user_id !== user.id || !rdv.share_id) return NextResponse.json({ ok: false });
      const { data: copies } = await admin.from("rendezvous").select("id, user_id").eq("share_id", rdv.share_id).neq("user_id", user.id);
      const moved = body.change === "moved";
      const results = [];
      for (const copy of (copies ?? []) as { id: string; user_id: string }[]) {
        const other = await profileOf(copy.user_id);
        const when = whenLabel(rdv.appointment_at, other?.timezone);
        const label = rdv.title ? `${rdv.title} — ${when}` : when;
        const text = moved
          ? { title: `${nameOf(me)} a déplacé votre rendez-vous`, body: `Nouvelle date : ${when}${rdv.title ? ` (${rdv.title})` : ""}.` }
          : rdv.status === "valide"
            ? { title: `${nameOf(me)} a confirmé votre rencontre ✅`, body: `${label}. Votre période est remise à zéro.` }
            : rdv.status === "annule"
              ? { title: `${nameOf(me)} a annulé votre rendez-vous`, body: label }
              : { title: `${nameOf(me)} a replanifié votre rendez-vous`, body: label };
        results.push(await notifyUser(admin, copy.user_id, { kind: "rdv_change", ...text, url: `/rdv/${copy.id}`, tag: `rdv-${copy.id}` }, { profile: other }));
      }
      return NextResponse.json({ ok: true, sent: results.length });
    } else {
      const { data: inv } = await admin.from("rdv_invitations").select("*").eq("id", id).maybeSingle();
      if (!inv) return NextResponse.json({ ok: false });
      const { data: rdv } = await admin.from("rendezvous").select("id, title, location, appointment_at").eq("id", inv.rdv_id).maybeSingle();
      if (!rdv) return NextResponse.json({ ok: false });

      if (type === "rdv_invite" && inv.from_user === user.id && inv.status === "pending") {
        target = inv.to_user;
        const other = await profileOf(inv.to_user);
        const details = [whenLabel(rdv.appointment_at, other?.timezone), rdv.location].filter(Boolean).join(" · ");
        payload = {
          kind: "rdv_invite",
          title: `${nameOf(me)} vous propose un rendez-vous`,
          body: `${rdv.title ? rdv.title + " — " : ""}${details}. Acceptez ou refusez dans SeeU.`,
          url: "/friends",
          tag: `invite-${id}`,
        };
        return NextResponse.json(await notifyUser(admin, inv.to_user, payload, { profile: other }));
      }
      if (type === "rdv_response" && inv.to_user === user.id && inv.status !== "pending") {
        target = inv.from_user;
        const other = await profileOf(inv.from_user);
        const accepted = inv.status === "accepted";
        payload = {
          kind: "rdv_response",
          title: accepted ? `${nameOf(me)} a accepté votre rendez-vous ✅` : `${nameOf(me)} a décliné votre rendez-vous`,
          body: `${rdv.title ? rdv.title + " — " : ""}${whenLabel(rdv.appointment_at, other?.timezone)}`,
          url: `/rdv/${rdv.id}`,
          tag: `invite-${id}`,
        };
        return NextResponse.json(await notifyUser(admin, inv.from_user, payload, { profile: other }));
      }
    }

    if (!target || !payload) return NextResponse.json({ ok: false });
    return NextResponse.json(await notifyUser(admin, target, payload));
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : "Erreur serveur" }, { status: 500 });
  }
}
