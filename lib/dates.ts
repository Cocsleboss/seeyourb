import {
  addDays,
  addMonths,
  addWeeks,
  addYears,
  differenceInCalendarDays,
  format,
  isToday,
  isTomorrow,
  isYesterday,
  parseISO,
} from "date-fns";
import { fr } from "date-fns/locale";
import type { FrequencyUnit } from "./types";

/* ------------------------------------------------------------------ */
/*  Dates "jour" (YYYY-MM-DD, heure locale)                            */
/* ------------------------------------------------------------------ */

export function toISODate(d: Date): string {
  return format(d, "yyyy-MM-dd");
}

export function todayISO(): string {
  return toISODate(new Date());
}

/** Parse 'YYYY-MM-DD' en Date locale (minuit local). */
export function parseDate(iso: string): Date {
  return parseISO(iso);
}

/** Nombre de jours calendaires entre aujourd'hui et la date (négatif si passée). */
export function daysFromToday(iso: string): number {
  return differenceInCalendarDays(parseISO(iso), new Date());
}

export function addFrequency(iso: string, value: number, unit: FrequencyUnit): string {
  const d = parseISO(iso);
  const out =
    unit === "days"
      ? addDays(d, value)
      : unit === "weeks"
        ? addWeeks(d, value)
        : unit === "months"
          ? addMonths(d, value)
          : addYears(d, value);
  return toISODate(out);
}

/* ------------------------------------------------------------------ */
/*  Échéances de recontact                                              */
/* ------------------------------------------------------------------ */

export type DueKind = "overdue" | "today" | "soon" | "ok";

export interface DueInfo {
  kind: DueKind;
  /** jours restants (négatif = retard) */
  days: number;
  /** ex. "En retard de 3 jours", "À revoir aujourd'hui", "À revoir dans 2 semaines" */
  label: string;
  /** version courte, ex. "-3 j", "Auj.", "2 sem." */
  short: string;
  /** YYYY-MM-DD effectivement utilisée (tient compte d'un report) */
  dueDate: string;
}

/** Date d'échéance effective : le report (snooze) repousse l'échéance calculée. */
export function effectiveDueDate(c: { next_due_date: string; snooze_until: string | null }): string {
  if (c.snooze_until && c.snooze_until > c.next_due_date) return c.snooze_until;
  return c.next_due_date;
}

export function getDueInfo(c: { next_due_date: string; snooze_until: string | null }): DueInfo {
  const dueDate = effectiveDueDate(c);
  const days = daysFromToday(dueDate);
  if (days < 0) {
    return {
      kind: "overdue",
      days,
      dueDate,
      label: `En retard de ${humanizeDays(-days)}`,
      short: `-${shortDays(-days)}`,
    };
  }
  if (days === 0) {
    return { kind: "today", days, dueDate, label: "À revoir aujourd'hui", short: "Auj." };
  }
  if (days <= 7) {
    return { kind: "soon", days, dueDate, label: `À revoir dans ${humanizeDays(days)}`, short: shortDays(days) };
  }
  return { kind: "ok", days, dueDate, label: `À revoir dans ${humanizeDays(days)}`, short: shortDays(days) };
}

/** 3 → "3 jours", 15 → "2 semaines", 95 → "3 mois", 400 → "1 an", 550 → "1 an et demi" */
export function humanizeDays(n: number): string {
  n = Math.abs(Math.round(n));
  if (n < 14) return n <= 1 ? `${n} jour` : `${n} jours`;
  if (n < 60) {
    const w = Math.round(n / 7);
    return `${w} semaine${w > 1 ? "s" : ""}`;
  }
  if (n < 350) {
    const m = Math.max(2, Math.round(n / 30.44));
    return `${m} mois`;
  }
  const years = Math.floor(n / 365.25);
  const rest = n - years * 365.25;
  if (years >= 1 && rest >= 140 && rest < 230) return `${years} an${years > 1 ? "s" : ""} et demi`;
  const y = Math.max(1, Math.round(n / 365.25));
  return `${y} an${y > 1 ? "s" : ""}`;
}

function shortDays(n: number): string {
  n = Math.abs(n);
  if (n < 14) return `${n} j`;
  if (n < 60) return `${Math.round(n / 7)} sem.`;
  if (n < 350) return `${Math.max(2, Math.round(n / 30.44))} mois`;
  const y = Math.max(1, Math.round(n / 365.25));
  return `${y} an${y > 1 ? "s" : ""}`;
}

/** (2, 'months') → "tous les 2 mois" ; (1, 'weeks') → "toutes les semaines" */
export function frequencyLabel(value: number, unit: FrequencyUnit): string {
  if (value === 1) {
    return { days: "tous les jours", weeks: "toutes les semaines", months: "tous les mois", years: "tous les ans" }[unit];
  }
  const names: Record<FrequencyUnit, string> = { days: "jours", weeks: "semaines", months: "mois", years: "ans" };
  return `${unit === "weeks" ? "toutes" : "tous"} les ${value} ${names[unit]}`;
}

export const FREQUENCY_UNIT_LABEL: Record<FrequencyUnit, [string, string]> = {
  days: ["jour", "jours"],
  weeks: ["semaine", "semaines"],
  months: ["mois", "mois"],
  years: ["an", "ans"],
};

/* ------------------------------------------------------------------ */
/*  Formatage                                                           */
/* ------------------------------------------------------------------ */

export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

/** '2025-11-12' → '12 nov. 2025' */
export function formatDate(iso: string, pattern = "d MMM yyyy"): string {
  return format(parseISO(iso), pattern, { locale: fr });
}

/** '2025-11-12' → 'mercredi 12 novembre 2025' */
export function formatDateLong(iso: string): string {
  return format(parseISO(iso), "EEEE d MMMM yyyy", { locale: fr });
}

/** ISO timestamp → 'mer. 12 nov. à 18:30' */
export function formatDateTime(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return format(d, "EEE d MMM 'à' HH:mm", { locale: fr });
}

export function formatTime(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return format(d, "HH:mm", { locale: fr });
}

/** "Aujourd'hui" / "Demain" / "Hier" / "mercredi 12 novembre" */
export function relativeDayLabel(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  if (isToday(d)) return "Aujourd'hui";
  if (isTomorrow(d)) return "Demain";
  if (isYesterday(d)) return "Hier";
  return capitalize(format(d, "EEEE d MMMM", { locale: fr }));
}

/** Clé de regroupement par jour (locale) */
export function dayKey(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return format(d, "yyyy-MM-dd");
}

export function monthKey(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return format(d, "yyyy-MM");
}

/** 'novembre 2025' */
export function monthLabel(ts: string | Date): string {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return capitalize(format(d, "MMMM yyyy", { locale: fr }));
}

/** Valeurs pour <input type="date"> et <input type="time"> à partir d'un instant. */
export function splitDateTime(ts: string | Date): { date: string; time: string } {
  const d = typeof ts === "string" ? new Date(ts) : ts;
  return { date: format(d, "yyyy-MM-dd"), time: format(d, "HH:mm") };
}

/** ('2025-11-12', '18:30') → Date locale */
export function combineDateTime(date: string, time: string): Date {
  const [y, m, d] = date.split("-").map(Number);
  const [hh, mm] = (time || "12:00").split(":").map(Number);
  return new Date(y, m - 1, d, hh || 0, mm || 0, 0, 0);
}

/** Heure arrondie au prochain quart d'heure (pour pré-remplir un formulaire). */
export function nextQuarterHour(from = new Date()): Date {
  const d = new Date(from);
  d.setSeconds(0, 0);
  const q = Math.ceil((d.getMinutes() + 1) / 15) * 15;
  d.setMinutes(q);
  return d;
}

/** Prochain anniversaire : jours restants (0 = aujourd'hui) et âge atteint. */
export function nextBirthday(birthday: string | null | undefined): { days: number; age: number } | null {
  if (!birthday) return null;
  const b = parseISO(birthday);
  if (Number.isNaN(b.getTime())) return null;
  const now = new Date();
  let next = new Date(now.getFullYear(), b.getMonth(), b.getDate());
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (next < today) next = new Date(now.getFullYear() + 1, b.getMonth(), b.getDate());
  const days = differenceInCalendarDays(next, today);
  return { days, age: next.getFullYear() - b.getFullYear() };
}

/** Salutation selon l'heure. */
export function greeting(d = new Date()): string {
  const h = d.getHours();
  if (h < 5) return "Bonne nuit";
  if (h < 12) return "Bonjour";
  if (h < 18) return "Bon après-midi";
  return "Bonsoir";
}
