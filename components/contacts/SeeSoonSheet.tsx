"use client";

import { Search } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Avatar, DueBadge, Input, Sheet, useToast } from "@/components/ui";
import { setSeeSoon } from "@/lib/data";
import { matchesQuery } from "@/lib/text";
import type { Contact } from "@/lib/types";

/**
 * Ajoute quelqu'un à la liste « à voir bientôt » même si son échéance est loin
 * (ex. on a croisé un ami qui ne va pas bien). Le marqueur disparaît tout seul dès qu'on s'est revus.
 */
export function SeeSoonSheet({
  contacts,
  open,
  onClose,
  onDone,
}: {
  /** contacts qui ne sont pas déjà dans la liste */
  contacts: Contact[];
  open: boolean;
  onClose: () => void;
  onDone: () => void;
}) {
  const toast = useToast();
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  useEffect(() => {
    if (open) setQuery("");
  }, [open]);

  const visible = useMemo(
    () => contacts.filter((c) => matchesQuery(c.name, query) || matchesQuery(c.category, query)),
    [contacts, query]
  );

  const pick = async (c: Contact) => {
    setBusy(c.id);
    try {
      await setSeeSoon(c.id, true);
      toast.success(`${c.name} ajouté(e) à la liste « à voir bientôt »`);
      onDone();
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Ajout impossible");
    } finally {
      setBusy(null);
    }
  };

  return (
    <Sheet open={open} onClose={onClose} title="À voir bientôt">
      <p className="text-sm text-gray-600 dark:text-gray-300">
        Choisissez quelqu&apos;un à revoir sans attendre la fin de sa période. Il restera en tête de liste jusqu&apos;à votre prochaine rencontre.
      </p>
      <div className="relative mt-3">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
        <Input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Rechercher un contact…" className="pl-11" aria-label="Rechercher un contact" />
      </div>
      <div className="mt-2 min-h-[30dvh]">
        {visible.length === 0 ? (
          <p className="px-1 py-6 text-center text-sm text-gray-500">
            {contacts.length === 0 ? "Tous vos contacts sont déjà dans la liste." : "Aucun contact ne correspond."}
          </p>
        ) : (
          <ul className="divide-y divide-gray-100 dark:divide-gray-800">
            {visible.map((c) => (
              <li key={c.id}>
                <button
                  type="button"
                  disabled={busy !== null}
                  onClick={() => pick(c)}
                  className="flex w-full items-center gap-3 px-1 py-2.5 text-left transition active:bg-gray-100 disabled:opacity-50 dark:active:bg-gray-800"
                >
                  <Avatar name={c.name} path={c.photo_path} size={38} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[15px] font-medium text-gray-900 dark:text-gray-100">{c.name}</span>
                    {c.category && <span className="block truncate text-xs text-gray-500">{c.category}</span>}
                  </span>
                  <DueBadge contact={c} short />
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    </Sheet>
  );
}
