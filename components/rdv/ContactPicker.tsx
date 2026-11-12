"use client";

import { Check, Search, X } from "lucide-react";
import { useMemo, useState } from "react";
import { Avatar, Card, EmptyState, Input, LinkButton, ListSkeleton } from "@/components/ui";
import { matchesQuery } from "@/lib/text";
import type { Contact } from "@/lib/types";

/** Sélection multiple de contacts (participants d'un rendez-vous). */
export function ContactPicker({
  contacts,
  selected,
  onChange,
  loading = false,
}: {
  contacts: Contact[];
  selected: string[];
  onChange: (ids: string[]) => void;
  loading?: boolean;
}) {
  const [query, setQuery] = useState("");
  const selectedSet = new Set(selected);

  const sorted = useMemo(() => [...contacts].sort((a, b) => a.name.localeCompare(b.name, "fr")), [contacts]);
  const visible = useMemo(() => sorted.filter((c) => matchesQuery(c.name, query) || matchesQuery(c.category, query)), [sorted, query]);
  const selectedContacts = selected.map((id) => contacts.find((c) => c.id === id)).filter((c): c is Contact => Boolean(c));

  const toggle = (id: string) => {
    onChange(selectedSet.has(id) ? selected.filter((x) => x !== id) : [...selected, id]);
  };

  if (loading && !contacts.length) return <ListSkeleton rows={3} />;

  if (!contacts.length) {
    return (
      <EmptyState
        className="py-6"
        title="Aucun contact"
        description="Créez d'abord un contact pour pouvoir planifier un rendez-vous."
        action={<LinkButton href="/contacts/new">Créer un contact</LinkButton>}
      />
    );
  }

  return (
    <div className="space-y-2">
      {selectedContacts.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {selectedContacts.map((c) => (
            <span
              key={c.id}
              className="inline-flex items-center gap-1.5 rounded-full bg-brand-100 py-1 pl-1 pr-2 text-sm font-medium text-brand-800 dark:bg-brand-900/40 dark:text-brand-100"
            >
              <Avatar name={c.name} path={c.photo_path} size={22} />
              {c.name}
              <button
                type="button"
                onClick={() => toggle(c.id)}
                aria-label={`Retirer ${c.name}`}
                className="ml-0.5 flex h-5 w-5 items-center justify-center rounded-full hover:bg-brand-200 dark:hover:bg-brand-800"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </span>
          ))}
        </div>
      )}
      <div className="relative">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
        <Input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Rechercher un contact…"
          className="pl-11"
          aria-label="Rechercher un contact"
        />
      </div>
      <Card className="max-h-64 overflow-y-auto p-0">
        {visible.length === 0 ? (
          <p className="px-4 py-6 text-center text-sm text-gray-500">Aucun contact ne correspond.</p>
        ) : (
          <ul className="divide-y divide-gray-100 dark:divide-gray-800">
            {visible.map((c) => {
              const active = selectedSet.has(c.id);
              return (
                <li key={c.id}>
                  <button
                    type="button"
                    onClick={() => toggle(c.id)}
                    aria-pressed={active}
                    className="flex w-full items-center gap-3 px-3 py-2.5 text-left transition active:bg-gray-100 dark:active:bg-gray-800"
                  >
                    <Avatar name={c.name} path={c.photo_path} size={36} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[15px] font-medium text-gray-900 dark:text-gray-100">{c.name}</span>
                      {c.category && <span className="block truncate text-xs text-gray-500">{c.category}</span>}
                    </span>
                    <span
                      className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 ${
                        active ? "border-brand-600 bg-brand-600 text-white" : "border-gray-300 dark:border-gray-600"
                      }`}
                      aria-hidden
                    >
                      {active && <Check className="h-4 w-4" strokeWidth={3} />}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </Card>
    </div>
  );
}
