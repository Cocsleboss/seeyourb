"use client";

import { getDueInfo, type DueKind } from "@/lib/dates";

export const DUE_PILL: Record<DueKind, string> = {
  overdue: "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
  today: "bg-orange-100 text-orange-800 dark:bg-orange-900/40 dark:text-orange-200",
  soon: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
  ok: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200",
};

export const DUE_TEXT: Record<DueKind, string> = {
  overdue: "text-red-600 dark:text-red-400",
  today: "text-orange-600 dark:text-orange-400",
  soon: "text-amber-600 dark:text-amber-400",
  ok: "text-emerald-600 dark:text-emerald-400",
};

export const DUE_DOT: Record<DueKind, string> = {
  overdue: "bg-red-500",
  today: "bg-orange-500",
  soon: "bg-amber-500",
  ok: "bg-emerald-500",
};

/** Pastille "En retard de 3 jours" / "À revoir dans 2 semaines". */
export function DueBadge({
  contact,
  short = false,
  className = "",
}: {
  contact: { next_due_date: string; snooze_until: string | null };
  short?: boolean;
  className?: string;
}) {
  const info = getDueInfo(contact);
  return (
    <span
      className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-semibold ${DUE_PILL[info.kind]} ${className}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${DUE_DOT[info.kind]}`} aria-hidden />
      {short ? info.short : info.label}
    </span>
  );
}
