"use client";

import { Calendar, CalendarPlus, Check, Clock, Settings, Sparkles, UserPlus } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { ContactRow } from "@/components/contacts/ContactRow";
import { MarkSeenSheet } from "@/components/contacts/MarkSeenSheet";
import { SnoozeSheet } from "@/components/contacts/SnoozeSheet";
import { Fab } from "@/components/Fab";
import { PushBanner } from "@/components/PushBanner";
import { RdvRow } from "@/components/rdv/RdvRow";
import { RdvStatusActions } from "@/components/rdv/RdvStatusActions";
import { Button, Card, DueBadge, EmptyState, LinkButton, ListSkeleton, Page, RowList, SectionTitle } from "@/components/ui";
import { listContacts, listPlannedRdv } from "@/lib/data";
import { capitalize, dayKey, getDueInfo, greeting, relativeDayLabel } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { useSession } from "@/lib/session";
import type { Contact, RendezvousWithContacts } from "@/lib/types";

const MAX_DUE = 8;
const MAX_UPCOMING = 10;

export default function HomePage() {
  const { profile } = useSession();
  const { data, loading, error, reload } = useAsyncData(() => Promise.all([listContacts(), listPlannedRdv()]), []);
  const [seenContact, setSeenContact] = useState<Contact | null>(null);
  const [snoozeContact, setSnoozeContact] = useState<Contact | null>(null);

  const contacts = useMemo(() => data?.[0] ?? [], [data]);
  const planned = useMemo(() => data?.[1] ?? [], [data]);

  const now = Date.now();
  const toConfirm = useMemo(() => planned.filter((r) => new Date(r.appointment_at).getTime() < now - 30 * 60_000), [planned, now]);
  const upcoming = useMemo(() => planned.filter((r) => new Date(r.appointment_at).getTime() >= now - 30 * 60_000), [planned, now]);

  const due = useMemo(
    () =>
      contacts
        .map((c) => ({ c, info: getDueInfo(c) }))
        .filter((x) => x.info.kind !== "ok")
        .sort((a, b) => a.info.days - b.info.days || a.c.name.localeCompare(b.c.name, "fr")),
    [contacts]
  );
  const overdueCount = due.filter((x) => x.info.kind === "overdue").length;

  const upcomingGroups = useMemo(() => {
    const groups: { key: string; label: string; items: RendezvousWithContacts[] }[] = [];
    for (const r of upcoming.slice(0, MAX_UPCOMING)) {
      const key = dayKey(r.appointment_at);
      let g = groups.find((x) => x.key === key);
      if (!g) {
        g = { key, label: relativeDayLabel(r.appointment_at), items: [] };
        groups.push(g);
      }
      g.items.push(r);
    }
    return groups;
  }, [upcoming]);

  const firstName = profile?.display_name?.trim().split(/\s+/)[0];

  return (
    <>
      <Page className="space-y-5 pt-[max(1rem,env(safe-area-inset-top))]">
        <header className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <h1 className="truncate text-2xl font-bold text-gray-900 dark:text-gray-100">
              {greeting()}
              {firstName ? ` ${firstName}` : ""} 👋
            </h1>
            <p className="text-sm text-gray-500 dark:text-gray-400">{capitalize(format(new Date(), "EEEE d MMMM", { locale: fr }))}</p>
          </div>
          <Link
            href="/settings"
            aria-label="Réglages"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-gray-600 hover:bg-gray-100 dark:text-gray-300 dark:hover:bg-gray-800"
          >
            <Settings className="h-5 w-5" />
          </Link>
        </header>

        <PushBanner />

        {loading && !data ? (
          <ListSkeleton rows={5} />
        ) : error && !data ? (
          <Card className="space-y-3 border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/20">
            <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
            <Button variant="secondary" onClick={() => reload(false)}>
              Réessayer
            </Button>
          </Card>
        ) : contacts.length === 0 ? (
          <Card>
            <EmptyState
              icon={<Sparkles className="h-7 w-7" />}
              title="Bienvenue sur SeeYourB"
              description="Ajoutez les personnes que vous voulez revoir régulièrement, choisissez une fréquence, et laissez l'app vous rappeler quand il est temps de les recontacter."
              action={
                <LinkButton href="/contacts/new" size="lg">
                  <UserPlus className="h-5 w-5" /> Ajouter mon premier contact
                </LinkButton>
              }
            />
          </Card>
        ) : (
          <>
            {/* Stats */}
            <div className="grid grid-cols-3 gap-2">
              <Stat label={contacts.length > 1 ? "contacts" : "contact"} value={contacts.length} href="/contacts" />
              <Stat label="en retard" value={overdueCount} href="/contacts" tone={overdueCount > 0 ? "danger" : "default"} />
              <Stat label={upcoming.length > 1 ? "rdv à venir" : "rdv à venir"} value={upcoming.length} />
            </div>

            {/* À confirmer */}
            {toConfirm.length > 0 && (
              <section>
                <SectionTitle>À confirmer</SectionTitle>
                <div className="space-y-2">
                  {toConfirm.map((r) => (
                    <Card key={r.id} className="overflow-hidden p-0">
                      <RdvRow rdv={r} />
                      <div className="px-4 pb-3">
                        <RdvStatusActions rdv={r} size="sm" onChanged={() => reload()} />
                      </div>
                    </Card>
                  ))}
                </div>
              </section>
            )}

            {/* À recontacter */}
            <section>
              <SectionTitle
                action={
                  due.length > MAX_DUE ? (
                    <Link href="/contacts" className="text-sm font-medium text-brand-600 dark:text-brand-300">
                      Voir tout ({due.length})
                    </Link>
                  ) : undefined
                }
              >
                À recontacter
              </SectionTitle>
              {due.length === 0 ? (
                <Card className="border-emerald-200 bg-emerald-50 dark:border-emerald-900/60 dark:bg-emerald-900/20">
                  <p className="font-semibold text-emerald-900 dark:text-emerald-100">Tout est à jour 🎉</p>
                  <p className="mt-0.5 text-sm text-emerald-800/80 dark:text-emerald-200/80">Personne à recontacter pour l&apos;instant.</p>
                </Card>
              ) : (
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {due.slice(0, MAX_DUE).map(({ c }) => (
                      <div key={c.id}>
                        <ContactRow contact={c} right={<DueBadge contact={c} short />} />
                        <div className="flex gap-2 px-4 pb-3">
                          <LinkButton href={`/rdv/new?contact=${c.id}`} size="sm" className="flex-1">
                            <CalendarPlus className="h-4 w-4" /> Planifier
                          </LinkButton>
                          <Button size="sm" variant="secondary" className="flex-1" onClick={() => setSeenContact(c)}>
                            <Check className="h-4 w-4" /> Vu
                          </Button>
                          <Button size="sm" variant="secondary" className="flex-1" onClick={() => setSnoozeContact(c)}>
                            <Clock className="h-4 w-4" /> Reporter
                          </Button>
                        </div>
                      </div>
                    ))}
                  </RowList>
                </Card>
              )}
            </section>

            {/* Prochains rendez-vous */}
            <section>
              <SectionTitle>Prochains rendez-vous</SectionTitle>
              {upcoming.length === 0 ? (
                <Card>
                  <EmptyState
                    className="py-4"
                    icon={<Calendar className="h-6 w-6" />}
                    title="Aucun rendez-vous prévu"
                    description="Planifiez un moment avec quelqu'un que vous voulez revoir."
                    action={
                      <LinkButton href="/rdv/new" variant="secondary">
                        <CalendarPlus className="h-5 w-5" /> Planifier un rendez-vous
                      </LinkButton>
                    }
                  />
                </Card>
              ) : (
                <div className="space-y-3">
                  {upcomingGroups.map((g) => (
                    <div key={g.key}>
                      <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-500">{g.label}</p>
                      <Card className="overflow-hidden p-0">
                        <RowList>
                          {g.items.map((r) => (
                            <RdvRow key={r.id} rdv={r} showDay={false} />
                          ))}
                        </RowList>
                      </Card>
                    </div>
                  ))}
                  {upcoming.length > MAX_UPCOMING && (
                    <p className="text-center text-xs text-gray-500">+ {upcoming.length - MAX_UPCOMING} autres rendez-vous planifiés</p>
                  )}
                </div>
              )}
            </section>
          </>
        )}
      </Page>

      {contacts.length > 0 && <Fab />}

      <MarkSeenSheet contact={seenContact} open={seenContact !== null} onClose={() => setSeenContact(null)} onDone={() => reload()} />
      <SnoozeSheet contact={snoozeContact} open={snoozeContact !== null} onClose={() => setSnoozeContact(null)} onDone={() => reload()} />
    </>
  );
}

function Stat({ label, value, href, tone = "default" }: { label: string; value: number; href?: string; tone?: "default" | "danger" }) {
  const cls = `flex flex-col items-center rounded-2xl border px-2 py-3 text-center ${
    tone === "danger"
      ? "border-red-200 bg-red-50 text-red-700 dark:border-red-900/60 dark:bg-red-900/20 dark:text-red-200"
      : "border-gray-200/70 bg-white text-gray-900 dark:border-gray-800 dark:bg-gray-900 dark:text-gray-100"
  }`;
  const inner = (
    <>
      <span className="text-2xl font-bold leading-none">{value}</span>
      <span className="mt-1 text-[11px] font-medium uppercase tracking-wide opacity-70">{label}</span>
    </>
  );
  return href ? (
    <Link href={href} className={cls}>
      {inner}
    </Link>
  ) : (
    <div className={cls}>{inner}</div>
  );
}
