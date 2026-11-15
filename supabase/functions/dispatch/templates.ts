// Notification texts, rendered in the recipient's language and time zone.
// The database only stores a `kind` and `params`; adding a language = adding a
// block below (plus the app strings). Unknown languages fall back to French.

export interface Rendered {
  title: string;
  body: string;
}

type Params = Record<string, unknown>;
type Lang = "fr" | "en";

interface Ctx {
  p: Params;
  tz: string;
  lang: Lang;
}

const str = (v: unknown): string | null => (typeof v === "string" && v.trim() ? v.trim() : null);
const list = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string" && !!x) : []);

function when(at: unknown, ctx: Ctx, withTime = true): string {
  if (typeof at !== "string") return "";
  const d = new Date(at);
  const opts: Intl.DateTimeFormatOptions = withTime
    ? { weekday: "long", day: "numeric", month: "long", hour: "numeric", minute: "2-digit", timeZone: ctx.tz }
    : { weekday: "long", day: "numeric", month: "long", timeZone: ctx.tz };
  try {
    return new Intl.DateTimeFormat(ctx.lang === "fr" ? "fr-FR" : "en-GB", opts).format(d);
  } catch {
    return new Intl.DateTimeFormat(ctx.lang === "fr" ? "fr-FR" : "en-GB", { ...opts, timeZone: "Europe/Paris" }).format(d);
  }
}

function time(at: unknown, ctx: Ctx): string {
  if (typeof at !== "string") return "";
  const opts: Intl.DateTimeFormatOptions = { hour: "numeric", minute: "2-digit", timeZone: ctx.tz };
  try {
    return new Intl.DateTimeFormat(ctx.lang === "fr" ? "fr-FR" : "en-GB", opts).format(new Date(at));
  } catch {
    return new Intl.DateTimeFormat("fr-FR", { ...opts, timeZone: "Europe/Paris" }).format(new Date(at));
  }
}

function names(v: string[], lang: Lang, max = 3): string {
  const and = lang === "fr" ? "et" : "and";
  if (v.length <= 1) return v[0] ?? "";
  if (v.length <= max) return `${v.slice(0, -1).join(", ")} ${and} ${v[v.length - 1]}`;
  const rest = v.length - max;
  const others = lang === "fr" ? `${rest} autre${rest > 1 ? "s" : ""}` : `${rest} other${rest > 1 ? "s" : ""}`;
  return `${v.slice(0, max).join(", ")} ${and} ${others}`;
}

/** "Titre — vendredi 4 décembre à 20:00 · Lieu" */
function eventLine(ctx: Ctx, opts: { place?: boolean } = {}): string {
  const { p, lang } = ctx;
  const title = str(p.title);
  const at = p.slots ? (lang === "fr" ? "date à choisir" : "date to be chosen") : when(p.at, ctx);
  const place = opts.place === false ? null : str(p.location);
  return [title ? `${title} — ${at}` : at, place].filter(Boolean).join(" · ");
}

const fr: Record<string, (c: Ctx) => Rendered> = {
  test: () => ({ title: "Notification de test ✅", body: "Les rappels SeeU fonctionnent sur cet appareil." }),
  friend_request: ({ p }) => ({
    title: `${p.name}${str(p.username) ? ` (@${p.username})` : ""} vous a ajouté sur SeeU`,
    body: "Acceptez sa demande pour partager vos rendez-vous et vos photos.",
  }),
  friend_accept: ({ p }) => ({ title: `${p.name} a accepté votre demande`, body: "Vous pouvez maintenant lui proposer des rendez-vous." }),
  wave: ({ p }) => ({
    title: `👋 ${p.name} aimerait vous voir`,
    body: p.has_contact
      ? "Proposez un rendez-vous : ce contact est en tête de votre liste « À voir bientôt »."
      : "Proposez un rendez-vous dans SeeU.",
  }),
  rdv_invite: (c) => ({
    title: c.p.past
      ? `${c.p.name} partage une rencontre avec vous`
      : c.p.slots ? `${c.p.name} cherche une date avec vous` : `${c.p.name} vous propose un rendez-vous`,
    body: `${eventLine(c)}. ${c.p.slots ? "Indiquez vos disponibilités dans SeeU." : "Acceptez ou refusez dans SeeU."}`,
  }),
  rdv_response: (c) => ({
    title: c.p.answer === "accepted" ? `${c.p.name} a accepté votre rendez-vous ✅` : `${c.p.name} a décliné votre rendez-vous`,
    body: eventLine(c, { place: false }),
  }),
  rdv_change: (c) => {
    const n = c.p.name;
    switch (c.p.change) {
      case "done": return { title: `${n} a confirmé votre rencontre ✅`, body: `${eventLine(c, { place: false })}. Votre période est remise à zéro.` };
      case "cancelled": return { title: `${n} a annulé le rendez-vous`, body: eventLine(c, { place: false }) };
      case "replanned": return { title: `${n} a replanifié le rendez-vous`, body: eventLine(c) };
      case "date_chosen": return { title: `📅 Date choisie par ${n}`, body: eventLine(c) };
      default: return { title: `${n} a déplacé le rendez-vous`, body: `Nouvelle date : ${eventLine(c)}` };
    }
  },
  rdv_reminder: (c) => {
    const m = Number(c.p.minutes ?? 30);
    const w = m <= 1 ? "maintenant" : m < 90 ? `dans ${Math.round(m)} min` : `à ${time(c.p.at, c)}`;
    const who = list(c.p.names);
    return {
      title: who.length ? `Rendez-vous avec ${names(who, "fr")} ${w}` : `Rendez-vous ${w}`,
      body: [str(c.p.title), when(c.p.at, c), str(c.p.location) ? `📍 ${c.p.location}` : null].filter(Boolean).join(" · "),
    };
  },
  rdv_followup: (c) => {
    const who = list(c.p.names);
    return {
      title: who.length ? `Votre rendez-vous avec ${names(who, "fr")} a-t-il eu lieu ?` : "Votre rendez-vous a-t-il eu lieu ?",
      body: "Confirmez-le pour mettre à jour la date de dernière rencontre, ou marquez-le comme annulé.",
    };
  },
  due_digest: ({ p }) => {
    const items = (Array.isArray(p.items) ? p.items : []) as { name: string; days: number }[];
    const count = Number(p.count ?? items.length);
    const parts = items.map((i) => `${i.name} (${i.days < 0 ? `en retard de ${-i.days} j` : i.days === 0 ? "aujourd'hui" : `dans ${i.days} j`})`);
    let body = parts.join(", ");
    if (count > items.length) body += ` et ${count - items.length} autre${count - items.length > 1 ? "s" : ""}`;
    const overdue = Number(p.overdue_total ?? 0);
    if (overdue > count) body += ` · ${overdue} en retard au total`;
    return { title: count === 1 ? `${items[0]?.name ?? "Un contact"} est à recontacter` : `${count} contacts à recontacter`, body };
  },
  birthday: ({ p }) => {
    const v = list(p.names);
    return v.length === 1
      ? { title: `🎂 C'est l'anniversaire de ${v[0]} !`, body: "Un petit message lui fera plaisir." }
      : { title: `🎂 ${v.length} anniversaires aujourd'hui`, body: names(v, "fr", 4) };
  },
  event_new: (c) => ({
    title: `${c.p.name} organise ${str(c.p.title) ?? "un événement"}`,
    body: `${eventLine(c)}. ${c.p.slots ? "Indiquez vos disponibilités" : "Rejoignez-le"} dans SeeU.`,
  }),
  event_join: (c) => ({ title: `${c.p.name} vient à ${str(c.p.title) ?? "votre événement"} 🎉`, body: eventLine(c, { place: false }) }),
  event_message: (c) => ({ title: `${c.p.name} · ${str(c.p.title) ?? "Discussion"}`, body: String(c.p.text ?? "") }),
  event_announcement: (c) => ({ title: `📣 ${str(c.p.title) ?? c.p.name}`, body: String(c.p.text ?? "") }),
};

const en: Record<string, (c: Ctx) => Rendered> = {
  test: () => ({ title: "Test notification ✅", body: "SeeU reminders work on this device." }),
  friend_request: ({ p }) => ({
    title: `${p.name}${str(p.username) ? ` (@${p.username})` : ""} added you on SeeU`,
    body: "Accept their request to share events and photos.",
  }),
  friend_accept: ({ p }) => ({ title: `${p.name} accepted your request`, body: "You can now invite them to events." }),
  wave: ({ p }) => ({
    title: `👋 ${p.name} would like to see you`,
    body: p.has_contact ? "Suggest an event: they're at the top of your “See soon” list." : "Suggest an event in SeeU.",
  }),
  rdv_invite: (c) => ({
    title: c.p.past
      ? `${c.p.name} shared a meetup with you`
      : c.p.slots ? `${c.p.name} is looking for a date with you` : `${c.p.name} invited you to an event`,
    body: `${eventLine(c)}. ${c.p.slots ? "Share your availability in SeeU." : "Accept or decline in SeeU."}`,
  }),
  rdv_response: (c) => ({
    title: c.p.answer === "accepted" ? `${c.p.name} accepted your event ✅` : `${c.p.name} declined your event`,
    body: eventLine(c, { place: false }),
  }),
  rdv_change: (c) => {
    const n = c.p.name;
    switch (c.p.change) {
      case "done": return { title: `${n} confirmed your meetup ✅`, body: `${eventLine(c, { place: false })}. Your period starts over.` };
      case "cancelled": return { title: `${n} cancelled the event`, body: eventLine(c, { place: false }) };
      case "replanned": return { title: `${n} rescheduled the event`, body: eventLine(c) };
      case "date_chosen": return { title: `📅 ${n} picked the date`, body: eventLine(c) };
      default: return { title: `${n} moved the event`, body: `New date: ${eventLine(c)}` };
    }
  },
  rdv_reminder: (c) => {
    const m = Number(c.p.minutes ?? 30);
    const w = m <= 1 ? "now" : m < 90 ? `in ${Math.round(m)} min` : `at ${time(c.p.at, c)}`;
    const who = list(c.p.names);
    return {
      title: who.length ? `Event with ${names(who, "en")} ${w}` : `Event ${w}`,
      body: [str(c.p.title), when(c.p.at, c), str(c.p.location) ? `📍 ${c.p.location}` : null].filter(Boolean).join(" · "),
    };
  },
  rdv_followup: (c) => {
    const who = list(c.p.names);
    return {
      title: who.length ? `Did your event with ${names(who, "en")} happen?` : "Did your event happen?",
      body: "Confirm it to update the last meetup date, or mark it as cancelled.",
    };
  },
  due_digest: ({ p }) => {
    const items = (Array.isArray(p.items) ? p.items : []) as { name: string; days: number }[];
    const count = Number(p.count ?? items.length);
    const parts = items.map((i) => `${i.name} (${i.days < 0 ? `${-i.days}d overdue` : i.days === 0 ? "today" : `in ${i.days}d`})`);
    let body = parts.join(", ");
    if (count > items.length) body += ` and ${count - items.length} more`;
    const overdue = Number(p.overdue_total ?? 0);
    if (overdue > count) body += ` · ${overdue} overdue in total`;
    return { title: count === 1 ? `Time to catch up with ${items[0]?.name ?? "a contact"}` : `${count} contacts to catch up with`, body };
  },
  birthday: ({ p }) => {
    const v = list(p.names);
    return v.length === 1
      ? { title: `🎂 It's ${v[0]}'s birthday!`, body: "A little message will make their day." }
      : { title: `🎂 ${v.length} birthdays today`, body: names(v, "en", 4) };
  },
  event_new: (c) => ({
    title: `${c.p.name} is organizing ${str(c.p.title) ?? "an event"}`,
    body: `${eventLine(c)}. ${c.p.slots ? "Share your availability" : "Join"} in SeeU.`,
  }),
  event_join: (c) => ({ title: `${c.p.name} is coming to ${str(c.p.title) ?? "your event"} 🎉`, body: eventLine(c, { place: false }) }),
  event_message: (c) => ({ title: `${c.p.name} · ${str(c.p.title) ?? "Chat"}`, body: String(c.p.text ?? "") }),
  event_announcement: (c) => ({ title: `📣 ${str(c.p.title) ?? c.p.name}`, body: String(c.p.text ?? "") }),
};

const templates: Record<Lang, Record<string, (c: Ctx) => Rendered>> = { fr, en };

export function render(kind: string, params: Params, locale: string | null, tz: string | null): Rendered | null {
  const lang: Lang = locale === "en" ? "en" : "fr";
  const t = templates[lang][kind] ?? fr[kind];
  if (!t) return null;
  return t({ p: params ?? {}, tz: tz || "Europe/Paris", lang });
}

export const emailChrome: Record<Lang, { more: string; unsubscribe: string }> = {
  fr: {
    more: "Ouvrez l'application SeeU pour en savoir plus.",
    unsubscribe: "Vous pouvez désactiver ces emails dans Réglages → Notifications.",
  },
  en: {
    more: "Open the SeeU app to find out more.",
    unsubscribe: "You can turn these emails off in Settings → Notifications.",
  },
};
