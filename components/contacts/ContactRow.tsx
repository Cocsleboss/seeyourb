"use client";

import { ChevronRight } from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";
import { Avatar, DueBadge } from "@/components/ui";
import { formatDate, frequencyLabel } from "@/lib/dates";
import type { Contact } from "@/lib/types";

/** Ligne de liste pour un contact (avatar, nom, sous-titre, pastille d'échéance). */
export function ContactRow({
  contact,
  right,
  subtitle,
  href,
}: {
  contact: Contact;
  /** remplace la pastille d'échéance à droite */
  right?: ReactNode;
  subtitle?: ReactNode;
  href?: string;
}) {
  return (
    <Link
      href={href ?? `/contacts/${contact.id}`}
      className="flex items-center gap-3 px-4 py-3 transition active:bg-gray-100 dark:active:bg-gray-800"
    >
      <Avatar name={contact.name} path={contact.photo_path} size={46} />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[15px] font-semibold text-gray-900 dark:text-gray-100">{contact.name}</p>
        <p className="truncate text-xs text-gray-500 dark:text-gray-400">
          {subtitle ?? (
            <>
              Vu le {formatDate(contact.last_meeting_date)} · {frequencyLabel(contact.frequency_value, contact.frequency_unit)}
            </>
          )}
        </p>
      </div>
      {right ?? <DueBadge contact={contact} short />}
      <ChevronRight className="h-4 w-4 shrink-0 text-gray-300 dark:text-gray-600" />
    </Link>
  );
}
