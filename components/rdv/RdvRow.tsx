"use client";

import { Camera, MapPin } from "lucide-react";
import Link from "next/link";
import { AvatarStack, StatusPill } from "@/components/ui";
import { formatTime, relativeDayLabel } from "@/lib/dates";
import type { RendezvousWithContacts } from "@/lib/types";
import { format } from "date-fns";
import { fr } from "date-fns/locale";

export function rdvTitle(rdv: RendezvousWithContacts): string {
  if (rdv.title) return rdv.title;
  const names = rdv.contacts.map((c) => c.name);
  if (!names.length) return "Rendez-vous";
  if (names.length <= 3) return `Avec ${names.join(", ")}`;
  return `Avec ${names.slice(0, 2).join(", ")} et ${names.length - 2} autres`;
}

/** Ligne de liste pour un rendez-vous (bloc date, titre, heure/lieu, participants, statut). */
export function RdvRow({
  rdv,
  showStatus = false,
  showDay = true,
}: {
  rdv: RendezvousWithContacts;
  /** affiche la pastille de statut (historique) */
  showStatus?: boolean;
  /** affiche le bloc jour/mois à gauche (sinon seulement l'heure) */
  showDay?: boolean;
}) {
  const d = new Date(rdv.appointment_at);
  return (
    <Link
      href={`/rdv/${rdv.id}`}
      className="flex items-center gap-3 px-4 py-3 transition active:bg-gray-100 dark:active:bg-gray-800"
    >
      {showDay ? (
        <div className="flex w-12 shrink-0 flex-col items-center rounded-xl bg-brand-50 py-1.5 text-brand-700 dark:bg-gray-800 dark:text-brand-300">
          <span className="text-lg font-bold leading-none">{format(d, "d")}</span>
          <span className="text-[10px] font-semibold uppercase">{format(d, "MMM", { locale: fr }).replace(".", "")}</span>
        </div>
      ) : (
        <div className="w-12 shrink-0 text-center text-sm font-semibold text-brand-700 dark:text-brand-300">{formatTime(d)}</div>
      )}
      <div className="min-w-0 flex-1">
        <p className="truncate text-[15px] font-semibold text-gray-900 dark:text-gray-100">{rdvTitle(rdv)}</p>
        <p className="flex items-center gap-1 truncate text-xs text-gray-500 dark:text-gray-400">
          {showDay ? `${relativeDayLabel(d)} · ${formatTime(d)}` : relativeDayLabel(d)}
          {rdv.location && (
            <>
              <span>·</span>
              <MapPin className="h-3 w-3 shrink-0" />
              <span className="truncate">{rdv.location}</span>
            </>
          )}
          {rdv.photos.length > 0 && (
            <>
              <span>·</span>
              <Camera className="h-3 w-3 shrink-0" />
              {rdv.photos.length}
            </>
          )}
        </p>
      </div>
      <div className="flex shrink-0 flex-col items-end gap-1">
        {rdv.contacts.length > 0 && <AvatarStack people={rdv.contacts} size={26} max={3} />}
        {showStatus && <StatusPill status={rdv.status} />}
      </div>
    </Link>
  );
}
