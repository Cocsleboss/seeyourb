// SeeU — notification dispatcher.
//
// Called by the database (pg_net) whenever a notification is queued, and every
// minute by pg_cron as a safety net. Delivers each pending row of
// public.notifications: push on every device of the user (FCM HTTP v1, which
// also covers iOS through APNs), falling back to email when no device got it.
//
// Secrets (supabase secrets set …):
//   DISPATCH_SECRET        same value as the vault secret 'dispatch_secret'
//   FCM_SERVICE_ACCOUNT    JSON of a Firebase service account (Cloud Messaging)
//   EMAIL_FROM             optional, e.g. "SeeU <hello@example.com>"
//   BREVO_API_KEY | RESEND_API_KEY   optional, email fallback provider
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by the platform.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.49.4";

interface NotificationRow {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string | null;
  url: string | null;
  force_push: boolean;
}

interface ProfileRow {
  id: string;
  email: string | null;
  notify_push: boolean;
  notify_email: boolean;
}

const BATCH = 200;

Deno.serve(async (req) => {
  const secret = Deno.env.get("DISPATCH_SECRET");
  const auth = req.headers.get("authorization") ?? "";
  if (!secret || auth !== `Bearer ${secret}`) {
    return json({ error: "unauthorized" }, 401);
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  let processed = 0;
  const channels: Record<string, number> = { push: 0, email: 0, none: 0 };

  // Claim batches until nothing is left (claim = pending → sending, atomic per row).
  for (let round = 0; round < 10; round++) {
    const { data: pending, error } = await admin
      .from("notifications")
      .select("id")
      .eq("status", "pending")
      .order("created_at", { ascending: true })
      .limit(BATCH);
    if (error) return json({ error: error.message }, 500);
    if (!pending?.length) break;

    const { data: claimed, error: claimError } = await admin
      .from("notifications")
      .update({ status: "sending" })
      .in("id", pending.map((p) => p.id))
      .eq("status", "pending")
      .select("id, user_id, kind, title, body, url, force_push");
    if (claimError) return json({ error: claimError.message }, 500);
    const rows = (claimed ?? []) as NotificationRow[];
    if (!rows.length) continue;

    const userIds = [...new Set(rows.map((r) => r.user_id))];
    const [{ data: profiles }, { data: tokens }] = await Promise.all([
      admin.from("profiles").select("id, email, notify_push, notify_email").in("id", userIds),
      admin.from("device_tokens").select("user_id, token, platform").in("user_id", userIds),
    ]);
    const profileById = new Map((profiles as ProfileRow[] | null ?? []).map((p) => [p.id, p]));
    const tokensByUser = new Map<string, string[]>();
    for (const t of (tokens ?? []) as { user_id: string; token: string }[]) {
      tokensByUser.set(t.user_id, [...(tokensByUser.get(t.user_id) ?? []), t.token]);
    }

    await Promise.all(
      rows.map(async (n) => {
        const channel = await deliver(admin, n, profileById.get(n.user_id) ?? null, tokensByUser.get(n.user_id) ?? []);
        channels[channel]++;
        processed++;
        await admin
          .from("notifications")
          .update({ status: "sent", channel, sent_at: new Date().toISOString() })
          .eq("id", n.id);
      }),
    );
  }

  return json({ ok: true, processed, channels });
});

async function deliver(
  admin: SupabaseClient,
  n: NotificationRow,
  profile: ProfileRow | null,
  tokens: string[],
): Promise<"push" | "email" | "none"> {
  // 1) Push on every device
  const wantPush = n.force_push || (profile?.notify_push ?? true);
  let pushed = 0;
  if (wantPush && tokens.length && fcmConfigured()) {
    const stale: string[] = [];
    await Promise.all(
      tokens.map(async (token) => {
        const res = await sendFcm(token, n);
        if (res === "ok") pushed++;
        else if (res === "stale") stale.push(token);
      }),
    );
    if (stale.length) await admin.from("device_tokens").delete().in("token", stale);
  }
  if (pushed > 0) return "push";

  // 2) Email fallback
  if ((profile?.notify_email ?? true) && profile?.email && emailConfigured()) {
    const ok = await sendEmail(profile.email, n.title, n.body ?? "");
    if (ok) return "email";
  }
  return "none";
}

/* ------------------------------------------------------------------ */
/*  FCM HTTP v1                                                         */
/* ------------------------------------------------------------------ */

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let serviceAccount: ServiceAccount | null | undefined;
let cachedToken: { value: string; exp: number } | null = null;

function fcmConfigured(): boolean {
  if (serviceAccount === undefined) {
    try {
      const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
      serviceAccount = raw ? (JSON.parse(raw) as ServiceAccount) : null;
    } catch {
      serviceAccount = null;
    }
  }
  return serviceAccount !== null;
}

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;
  const sa = serviceAccount!;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${b64url(signature)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}: ${await res.text()}`);
  const body = (await res.json()) as { access_token: string; expires_in: number };
  cachedToken = { value: body.access_token, exp: now + body.expires_in };
  return body.access_token;
}

async function sendFcm(token: string, n: NotificationRow): Promise<"ok" | "stale" | "error"> {
  try {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount!.project_id}/messages:send`, {
      method: "POST",
      headers: { authorization: `Bearer ${await accessToken()}`, "content-type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: n.title, body: n.body ?? "" },
          data: { url: n.url ?? "/", kind: n.kind, notification_id: n.id },
          android: {
            priority: "high",
            notification: { channel_id: "seeu_default", tag: `${n.kind}-${n.url ?? ""}` },
          },
          apns: { payload: { aps: { sound: "default", "thread-id": n.kind } } },
        },
      }),
    });
    if (res.ok) return "ok";
    const text = await res.text();
    // Token no longer valid (app uninstalled, token rotated…)
    if (res.status === 404 || text.includes("UNREGISTERED") || (res.status === 400 && text.includes("registration token"))) {
      return "stale";
    }
    console.error("fcm", res.status, text);
    return "error";
  } catch (e) {
    console.error("fcm", e);
    return "error";
  }
}

/* ------------------------------------------------------------------ */
/*  Email (Brevo or Resend)                                             */
/* ------------------------------------------------------------------ */

function emailConfigured(): boolean {
  return Boolean(Deno.env.get("EMAIL_FROM") && (Deno.env.get("BREVO_API_KEY") || Deno.env.get("RESEND_API_KEY")));
}

function parseFrom(from: string): { name: string; email: string } {
  const m = from.match(/^\s*"?([^"<]*)"?\s*<([^>]+)>\s*$/);
  return m ? { name: m[1].trim() || "SeeU", email: m[2].trim() } : { name: "SeeU", email: from.trim() };
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

function renderHtml(title: string, body: string): string {
  return `<!doctype html><html><body style="margin:0;background:#f9fafb;font-family:-apple-system,Segoe UI,Roboto,sans-serif">
<div style="max-width:480px;margin:0 auto;padding:32px 20px">
<div style="background:#fff;border-radius:20px;padding:24px;border:1px solid #e5e7eb">
<p style="margin:0 0 4px;color:#4f46e5;font-weight:700">SeeU</p>
<h1 style="margin:0 0 12px;font-size:20px;color:#111827">${escapeHtml(title)}</h1>
<p style="margin:0;color:#374151;line-height:1.5">${escapeHtml(body)}</p>
<p style="margin:20px 0 0;color:#6b7280;font-size:13px">Ouvrez l'application SeeU pour en savoir plus.</p>
</div>
<p style="color:#9ca3af;font-size:12px;text-align:center;margin-top:16px">Vous pouvez désactiver ces emails dans Réglages → Notifications.</p>
</div></body></html>`;
}

async function sendEmail(to: string, subject: string, text: string): Promise<boolean> {
  const from = Deno.env.get("EMAIL_FROM")!;
  const html = renderHtml(subject, text);
  try {
    const brevo = Deno.env.get("BREVO_API_KEY");
    if (brevo) {
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: { "api-key": brevo, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ sender: parseFrom(from), to: [{ email: to }], subject, htmlContent: html, textContent: text }),
      });
      if (!res.ok) console.error("brevo", res.status, await res.text());
      return res.ok;
    }
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "content-type": "application/json" },
      body: JSON.stringify({ from, to, subject, html, text }),
    });
    if (!res.ok) console.error("resend", res.status, await res.text());
    return res.ok;
  } catch (e) {
    console.error("email", e);
    return false;
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
