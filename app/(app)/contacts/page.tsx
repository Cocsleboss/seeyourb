"use client";

import { BookUser, Plus, Search, UserPlus, Users } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { ContactRow } from "@/components/contacts/ContactRow";
import {
  Button,
  Card,
  Chip,
  ChipRow,
  EmptyState,
  Input,
  LinkButton,
  ListSkeleton,
  Page,
  RowList,
  SectionTitle,
  SegmentedControl,
  TopBar,
} from "@/components/ui";
import { listContacts } from "@/lib/data";
import { getDueInfo } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { matchesQuery, plural } from "@/lib/text";
import type { Contact } from "@/lib/types";

type Sort = "due" | "name";

export default function ContactsPage() {
  const { data: contacts, loading, error, reload } = useAsyncData(listContacts, []);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<string | null>(null);
  const [sort, setSort] = useState<Sort>("due");

  const categories = useMemo(
    () =>
      Array.from(new Set((contacts ?? []).map((c) => c.category).filter((c): c is string => Boolean(c)))).sort((a, b) =>
        a.localeCompare(b, "fr")
      ),
    [contacts]
  );

  const filtered = useMemo(() => {
    const list = (contacts ?? []).filter(
      (c) => (!category || c.category === category) && (matchesQuery(c.name, query) || matchesQuery(c.category, query) || matchesQuery(c.notes, query))
    );
    if (sort === "name") return [...list].sort((a, b) => a.name.localeCompare(b.name, "fr"));
    return [...list].sort((a, b) => {
      const d = getDueInfo(a).days - getDueInfo(b).days;
      return d !== 0 ? d : a.name.localeCompare(b.name, "fr");
    });
  }, [contacts, category, query, sort]);

  const groups = useMemo(() => {
    if (sort === "name") return [{ title: null as string | null, items: filtered }];
    const overdue: Contact[] = [];
    const week: Contact[] = [];
    const ok: Contact[] = [];
    filtered.forEach((c) => {
      const k = getDueInfo(c).kind;
      if (k === "overdue") overdue.push(c);
      else if (k === "today" || k === "soon") week.push(c);
      else ok.push(c);
    });
    return [
      { title: "En retard", items: overdue },
      { title: "Cette semaine", items: week },
      { title: "À jour", items: ok },
    ].filter((g) => g.items.length);
  }, [filtered, sort]);

  const overdueCount = (contacts ?? []).filter((c) => getDueInfo(c).kind === "overdue").length;

  return (
    <>
      <TopBar
        title="Contacts"
        right={
          <>
            <Link
              href="/contacts/import"
              aria-label="Importer des contacts du téléphone"
              title="Importer des contacts"
              className="flex h-10 w-10 items-center justify-center rounded-full text-brand-600 hover:bg-gray-100 active:scale-95 dark:text-brand-300 dark:hover:bg-gray-800"
            >
              <BookUser className="h-5 w-5" />
            </Link>
            <Link
              href="/contacts/new"
              aria-label="Ajouter un contact"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-600 text-white shadow-sm active:scale-95"
            >
              <Plus className="h-5 w-5" strokeWidth={2.5} />
            </Link>
          </>
        }
      />
      <Page className="space-y-4">
        {loading && !contacts ? (
          <ListSkeleton rows={6} />
        ) : error ? (
          <Card className="space-y-3 border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/20">
            <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
            <Button variant="secondary" onClick={() => reload(false)}>
              Réessayer
            </Button>
          </Card>
        ) : !contacts?.length ? (
          <EmptyState
            icon={<Users className="h-7 w-7" />}
            title="Aucun contact pour l'instant"
            description="Ajoutez les personnes que vous voulez revoir régulièrement : l'app vous rappellera quand il est temps de les recontacter."
            action={
              <div className="flex flex-col items-stretch gap-2">
                <LinkButton href="/contacts/new">
                  <UserPlus className="h-5 w-5" /> Ajouter un contact
                </LinkButton>
                <LinkButton href="/contacts/import" variant="secondary">
                  <BookUser className="h-5 w-5" /> Importer depuis le téléphone
                </LinkButton>
              </div>
            }
          />
        ) : (
          <>
            <div className="relative">
              <Search className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
              <Input
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Rechercher un contact"
                className="pl-11"
                aria-label="Rechercher un contact"
              />
            </div>

            {categories.length > 0 && (
              <ChipRow>
                <Chip active={category === null} onClick={() => setCategory(null)}>
                  Tous
                </Chip>
                {categories.map((c) => (
                  <Chip key={c} active={category === c} onClick={() => setCategory(category === c ? null : c)}>
                    {c}
                  </Chip>
                ))}
              </ChipRow>
            )}

            <div className="flex items-center justify-between gap-3">
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {plural(contacts.length, "contact")}
                {overdueCount > 0 && (
                  <>
                    {" · "}
                    <span className="font-medium text-red-600 dark:text-red-400">{overdueCount} en retard</span>
                  </>
                )}
              </p>
              <SegmentedControl<Sort>
                className="w-44"
                options={[
                  { value: "due", label: "Échéance" },
                  { value: "name", label: "Nom" },
                ]}
                value={sort}
                onChange={setSort}
              />
            </div>

            {filtered.length === 0 ? (
              <EmptyState icon={<Search className="h-6 w-6" />} title="Aucun résultat" description="Essayez un autre nom ou retirez le filtre." />
            ) : (
              groups.map((g) => (
                <section key={g.title ?? "all"}>
                  {g.title && (
                    <SectionTitle>
                      {g.title} <span className="font-normal text-gray-400">({g.items.length})</span>
                    </SectionTitle>
                  )}
                  <Card className="overflow-hidden p-0">
                    <RowList>
                      {g.items.map((c) => (
                        <ContactRow key={c.id} contact={c} />
                      ))}
                    </RowList>
                  </Card>
                </section>
              ))
            )}
          </>
        )}
      </Page>
    </>
  );
}
