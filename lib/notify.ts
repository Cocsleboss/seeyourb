/**
 * Envoi d'une notification à un utilisateur : push Web (tous ses appareils) en priorité,
 * email en secours si aucun push n'a pu être délivré. Journalise dans la table notifications.
 * Côté serveur uniquement (utilise la clé service role).
 */
import webpush from "web-push";
import type { SupabaseClient } from "@supabase/supabase-js";
import { emailConfigured, renderEmailHtml, sendEmail } from "@/lib/email";
import type { Profile, PushSubscriptionRow } from "@/lib/types";

let vapidReady = false;

export function pushConfigured(): boolean {
  return Boolean(process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY && process.env.VAPID_PRIVATE_KEY);
}

function ensureVapid() {
  if (vapidReady) return;
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || "mailto:admin@example.com",
    process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY!,
    process.env.VAPID_PRIVATE_KEY!
  );
  vapidReady = true;
}

export function appUrl(path = "/"): string {
  const base = (process.env.NEXT_PUBLIC_APP_URL || process.env.VERCEL_PROJECT_PRODUCTION_URL && `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` || "http://localhost:3000").replace(/\/$/, "");
  return path.startsWith("http") ? path : base + (path.startsWith("/") ? path : "/" + path);
}

export interface NotifyPayload {
  /** ex. 'due_digest', 'rdv_reminder', 'rdv_followup', 'birthday', 'test' */
  kind: string;
  title: string;
  body: string;
  /** chemin relatif ouvert au clic, ex. '/rdv/123' */
  url?: string;
  /** regroupe/remplace les notifications de même tag */
  tag?: string;
}

export interface NotifyResult {
  channel: "push" | "email" | "none";
  pushSent: number;
  pushFailed: number;
  emailSent: boolean;
  detail?: string;
}

export interface NotifyOptions {
  profile?: Profile | null;
  /** ignore la préférence notify_push (ex. bouton "tester") */
  forcePush?: boolean;
  /** envoie aussi l'email même si le push a fonctionné */
  alsoEmail?: boolean;
}

export async function notifyUser(
  admin: SupabaseClient,
  userId: string,
  payload: NotifyPayload,
  opts: NotifyOptions = {}
): Promise<NotifyResult> {
  const profile =
    opts.profile ?? ((await admin.from("profiles").select("*").eq("id", userId).maybeSingle()).data as Profile | null);

  const result: NotifyResult = { channel: "none", pushSent: 0, pushFailed: 0, emailSent: false };
  const url = payload.url ?? "/";

  // 1) Push
  const wantPush = opts.forcePush || (profile?.notify_push ?? true);
  if (wantPush) {
    if (!pushConfigured()) {
      result.detail = "push non configuré (clés VAPID manquantes)";
    } else {
      const { data: subs } = await admin.from("push_subscriptions").select("*").eq("user_id", userId);
      const list = (subs ?? []) as PushSubscriptionRow[];
      if (!list.length) {
        result.detail = "aucun appareil abonné aux notifications push";
      } else {
        ensureVapid();
        const body = JSON.stringify({ title: payload.title, body: payload.body, url, tag: payload.tag, kind: payload.kind });
        const outcomes = await Promise.allSettled(
          list.map((s) =>
            webpush.sendNotification(
              { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
              body,
              { TTL: 60 * 60 * 24, urgency: "high" }
            )
          )
        );
        const stale: string[] = [];
        outcomes.forEach((o, i) => {
          if (o.status === "fulfilled") {
            result.pushSent++;
          } else {
            result.pushFailed++;
            const err = o.reason as { statusCode?: number; body?: string; message?: string };
            if (err?.statusCode === 404 || err?.statusCode === 410) stale.push(list[i].endpoint);
            else console.error("web-push:", err?.statusCode, err?.body || err?.message);
            if (!result.detail) result.detail = `push refusé (${err?.statusCode ?? "?"})`;
          }
        });
        if (stale.length) await admin.from("push_subscriptions").delete().in("endpoint", stale);
        if (result.pushSent > 0) result.channel = "push";
      }
    }
  }

  // 2) Email en secours (ou en plus si demandé)
  const wantEmail = (profile?.notify_email ?? true) && (result.pushSent === 0 || opts.alsoEmail);
  if (wantEmail && profile?.email) {
    if (!emailConfigured()) {
      if (result.pushSent === 0) result.detail = (result.detail ? result.detail + " ; " : "") + "email non configuré";
    } else {
      const absolute = appUrl(url);
      const ok = await sendEmail({
        to: profile.email,
        subject: payload.title,
        text: `${payload.body}\n\n${absolute}`,
        html: renderEmailHtml({ title: payload.title, body: payload.body, url: absolute }),
      });
      result.emailSent = ok;
      if (ok && result.channel === "none") result.channel = "email";
      if (!ok && result.pushSent === 0) result.detail = (result.detail ? result.detail + " ; " : "") + "échec d'envoi de l'email";
    }
  }

  await admin.from("notifications").insert({
    user_id: userId,
    kind: payload.kind,
    title: payload.title,
    body: payload.body,
    url,
    channel: result.channel,
  });

  return result;
}

/** Vérifie le secret partagé du cron (header Authorization: Bearer <CRON_SECRET>). */
export function isCronAuthorized(req: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;
  const auth = req.headers.get("authorization") || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  const alt = req.headers.get("x-cron-secret") || new URL(req.url).searchParams.get("secret") || "";
  return token === secret || alt === secret;
}
