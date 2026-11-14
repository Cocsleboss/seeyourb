/**
 * Envoi d'emails transactionnels (canal de secours des notifications).
 * Fournisseurs supportés (le premier configuré est utilisé) :
 *   - Brevo  : BREVO_API_KEY  (gratuit, 300 mails/jour, expéditeur = email vérifié)
 *   - Resend : RESEND_API_KEY (gratuit, mais domaine vérifié requis pour écrire à d'autres adresses)
 * Dans les deux cas EMAIL_FROM doit être défini, ex. "SeeU <vous@exemple.com>".
 */

export function emailProvider(): "brevo" | "resend" | null {
  if (!process.env.EMAIL_FROM) return null;
  if (process.env.BREVO_API_KEY) return "brevo";
  if (process.env.RESEND_API_KEY) return "resend";
  return null;
}

export function emailConfigured(): boolean {
  return emailProvider() !== null;
}

function parseFrom(from: string): { name: string; email: string } {
  const m = from.match(/^\s*"?([^"<]*)"?\s*<([^>]+)>\s*$/);
  if (m) return { name: m[1].trim() || "SeeU", email: m[2].trim() };
  return { name: "SeeU", email: from.trim() };
}

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
  html: string;
}

export async function sendEmail(msg: EmailMessage): Promise<boolean> {
  const provider = emailProvider();
  const from = process.env.EMAIL_FROM || "";
  try {
    if (provider === "brevo") {
      const sender = parseFrom(from);
      const res = await fetch("https://api.brevo.com/v3/smtp/email", {
        method: "POST",
        headers: {
          "api-key": process.env.BREVO_API_KEY!,
          "content-type": "application/json",
          accept: "application/json",
        },
        body: JSON.stringify({
          sender,
          to: [{ email: msg.to }],
          subject: msg.subject,
          htmlContent: msg.html,
          textContent: msg.text,
        }),
      });
      if (!res.ok) console.error("Brevo:", res.status, await res.text());
      return res.ok;
    }
    if (provider === "resend") {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, "content-type": "application/json" },
        body: JSON.stringify({ from, to: [msg.to], subject: msg.subject, html: msg.html, text: msg.text }),
      });
      if (!res.ok) console.error("Resend:", res.status, await res.text());
      return res.ok;
    }
  } catch (e) {
    console.error("email:", e);
  }
  return false;
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/** Gabarit HTML simple et lisible sur mobile. */
export function renderEmailHtml(opts: { title: string; body: string; url: string; cta?: string }): string {
  const { title, body, url, cta = "Ouvrir SeeU" } = opts;
  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${escapeHtml(title)}</title></head>
<body style="margin:0;padding:0;background:#f4f4f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#111827;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f4f7;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;">
        <tr><td style="background:linear-gradient(135deg,#6366f1,#7c3aed);padding:20px 24px;color:#fff;font-size:18px;font-weight:700;">SeeU</td></tr>
        <tr><td style="padding:24px;">
          <h1 style="margin:0 0 12px;font-size:20px;line-height:1.3;">${escapeHtml(title)}</h1>
          <p style="margin:0 0 20px;font-size:16px;line-height:1.5;color:#374151;white-space:pre-line;">${escapeHtml(body)}</p>
          <a href="${escapeHtml(url)}" style="display:inline-block;background:#4f46e5;color:#fff;text-decoration:none;font-weight:600;padding:12px 20px;border-radius:12px;font-size:16px;">${escapeHtml(cta)}</a>
        </td></tr>
        <tr><td style="padding:16px 24px;font-size:12px;color:#6b7280;border-top:1px solid #e5e7eb;">Vous recevez cet email car les notifications push ne sont pas activées sur vos appareils. Vous pouvez changer vos préférences dans les réglages de l'application.</td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}
