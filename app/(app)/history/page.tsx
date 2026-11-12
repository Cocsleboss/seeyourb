"use client";

import { Clock, Search } from "lucide-react";
import { useMemo, useState } from "react";
import { RdvRow } from "@/components/rdv/RdvRow";
import { Button, Card, EmptyState, Input, ListSkeleton, Page, RowList, SectionTitle, SegmentedControl, TopBar } from "@/components/ui";
import { listHistory } from "@/lib/data";
import { monthKey, monthLabel } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { matchesQuery, plural } from "@/lib/text";
import type { RendezvousWithContacts } from "@/lib/types";

type Filter = "all" | "valide" | "annule";

export default function HistoryPage() {
  const { data: history, loading, error, reload } = useAsyncData(() => listHistory(), []);
  const [filter, setFilter] = useState<Filter>("all");
  const [query, setQuery] = useState("");

  const filtered = useMemo(
    () =>
      (history ?? []).filter(
        (r) =>
          (filter === "all" || r.status === filter) &&
          (matchesQuery(r.title, query) || matchesQuery(r.location, query) || r.contacts.some((c) => matchesQuery(c.name, query)))
      ),
    [history, filter, query]
  );

  const groups = useMemo(() => {
    const out: { key: string; label: string; items: RendezvousWithContacts[] }[] = [];
    for (const r of filtered) {
      const key = monthKey(r.appointment_at);
      let g = out.find((x) => x.key === key);
      if (!g) {
        g = { key, label: monthLabel(r.appointment_at), items: [] };
        out.push(g);
      }
      g.items.push(r);
    }
    return out;
  }, [filtered]);

  const doneCount = (history ?? []).filter((r) => r.status === "valide").length;
  const cancelledCount = (history ?? []).filter((r) => r.status === "annule").length;

  return (
    <>
      <TopBar title="Historique" />
      <Page className="space-y-4">
        {loading && !history ? (
          <ListSkeleton rows={6} />
        ) : error ? (
          <Card className="space-y-3 border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/20">
            <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
            <Button variant="secondary" onClick={() => reload(false)}>
              Réessayer
            </Button>
          </Card>
        ) : !history?.length ? (
          <EmptyState
            icon={<Clock className="h-7 w-7" />}
            title="Aucun rendez-vous passé"
            description="Les rendez-vous validés ou annulés apparaîtront ici, avec leurs photos."
          />
        ) : (
          <>
            <SegmentedControl<Filter>
              options={[
                { value: "all", label: "Tous" },
                { value: "valide", label: "A eu lieu" },
                { value: "annule", label: "Annulés" },
              ]}
              value={filter}
              onChange={setFilter}
            />
            <div className="relative">
              <Search className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
              <Input
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Rechercher (contact, titre, lieu)"
                className="pl-11"
                aria-label="Rechercher dans l'historique"
              />
            </div>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              {plural(doneCount, "rencontre")}
              {cancelledCount > 0 && ` · ${plural(cancelledCount, "annulé")}`}
            </p>

            {groups.length === 0 ? (
              <EmptyState icon={<Search className="h-6 w-6" />} title="Aucun résultat" description="Essayez un autre nom ou changez le filtre." />
            ) : (
              groups.map((g) => (
                <section key={g.key}>
                  <SectionTitle>
                    {g.label} <span className="font-normal text-gray-400">({g.items.length})</span>
                  </SectionTitle>
                  <Card className="overflow-hidden p-0">
                    <RowList>
                      {g.items.map((r) => (
                        <RdvRow key={r.id} rdv={r} showStatus />
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
