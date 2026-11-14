"use client";

import { Cake, Calendar, CalendarPlus, Check, Clock, Plus, Settings, Sparkles, Star, UserPlus, X } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import { format } from "date-fns";
import { fr } from "date-fns/locale";
import { ContactRow } from "@/components/contacts/ContactRow";
import { MarkSeenSheet } from "@/components/contacts/MarkSeenSheet";
import { SeeSoonSheet } from "@/components/contacts/SeeSoonSheet";
import { SnoozeSheet } from "@/components/contacts/SnoozeSheet";
import { Fab } from "@/components/Fab";
import { PushBanner } from "@/components/PushBanner";
import { RdvRow } from "@/components/rdv/RdvRow";
import { RdvStatusActions } from "@/components/rdv/RdvStatusActions";
import { IncomingInvites } from "@/components/social/IncomingInvites";
import { Avatar, Button, Card, DueBadge, EmptyState, LinkButton, ListSkeleton, Page, RowList, SectionTitle, useToast } from "@/components/ui";
import { listContacts, listIncomingInvites, listPlannedRdv, setSeeSoon } from "@/lib/data";
import { capitalize, dayKey, getDueInfo, greeting, nextBirthday, relativeDayLabel } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { useSession } from "@/lib/session";
import type { Contact, IncomingInvite, RendezvousWithContacts } from "@/lib/types";

const MAX_DUE = 8;
const MAX_UPCOMING = 10;

export default function HomePage() {
  const { profile } = useSession();
  const toast = useToast();
  const { data, loading, error, reload } = useAsyncData(
    // les invitations ne doivent jamais empêcher l'accueil de s'afficher
    () => Promise.all([listContacts(), listPlannedRdv(), listIncomingInvites().catch(() => [] as IncomingInvite[])]),
    []
  );
  const [seenContact, setSeenContact] = useState<Contact | null>(null);
  const [snoozeContact, setSnoozeContact] = useState<Contact | null>(null);
  const [seeSoonOpen, setSeeSoonOpen] = useState(false);

  const contacts = useMemo(() => data?.[0] ?? [], [data]);
  const planned = useMemo(() => data?.[1] ?? [], [data]);
  const invites = useMemo(() => data?.[2] ?? [], [data]);

  const now = Date.now();
  const toConfirm = useMemo(() => planned.filter((r) => new Date(r.appointment_at).getTime() < now - 30 * 60_000), [planned, now]);
  const upcoming = useMemo(() => planned.filter((r) => new Date(r.appointment_at).getTime() >= now - 30 * 60_000), [planned, now]);

  const due = useMemo(
    () =>
      contacts
        .map((c) => ({ c, info: getDueInfo(c) }))
        .filter((x) => x.info.kind !== "ok" || x.c.see_soon)
        // « à voir bientôt » en tête, puis du plus en retard au moins urgent
        .sort((a, b) => Number(b.c.see_soon) - Number(a.c.see_soon) || a.info.days - b.info.days || a.c.name.localeCompare(b.c.name, "fr")),
    [contacts]
  );
  const notInList = useMemo(() => {
    const ids = new Set(due.map((x) => x.c.id));
    return contacts.filter((c) => !ids.has(c.id));
  }, [contacts, due]);

  // Anniversaires : aujourd'hui (mis en avant) et dans les 7 jours
  const birthdays = useMemo(
    () =>
      contacts
        .map((c) => ({ c, b: nextBirthday(c.birthday) }))
        .filter((x): x is { c: Contact; b: { days: number; age: number } } => x.b !== null && x.b.days <= 7)
        .sort((a, b) => a.b.days - b.b.days || a.c.name.localeCompare(b.c.name, "fr")),
    [contacts]
  );
  const birthdaysToday = birthdays.filter((x) => x.b.days === 0);
  const birthdaysSoon = birthdays.filter((x) => x.b.days > 0);

  const removeSeeSoon = async (c: Contact) => {
    try {
      await setSeeSoon(c.id, false);
      toast.info(`${c.name} retiré(e) de la liste`);
      reload();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Action impossible");
    }
  };
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

        {invites.length > 0 && (
          <section>
            <SectionTitle>{invites.length > 1 ? "Invitations reçues" : "Invitation reçue"}</SectionTitle>
            <IncomingInvites invites={invites} onChanged={() => reload()} />
          </section>
        )}

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
              title="Bienvenue sur SeeU"
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
            {/* Anniversaires du jour */}
            {birthdaysToday.map(({ c, b }) => (
              <Card key={c.id} className="space-y-3 border-pink-200 bg-pink-50 dark:border-pink-900/60 dark:bg-pink-900/20">
                <Link href={`/contacts/${c.id}`} className="flex items-center gap-3">
                  <Avatar name={c.name} path={c.photo_path} size={46} />
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold text-pink-900 dark:text-pink-100">🎂 C&apos;est l&apos;anniversaire de {c.name} !</p>
                    <p className="text-sm text-pink-800/80 dark:text-pink-200/80">
                      {b.age > 0 && b.age < 120 ? `${b.age} ans aujourd'hui · ` : ""}Pensez à lui souhaiter.
                    </p>
                  </div>
                </Link>
                <div className="flex gap-2">
                  {c.phone && (
                    <a
                      href={`sms:${c.phone.replace(/\s+/g, "")}`}
                      className="inline-flex h-9 flex-1 items-center justify-center rounded-xl bg-pink-600 px-3 text-sm font-semibold text-white active:scale-[0.98]"
                    >
                      Envoyer un message
                    </a>
                  )}
                  <LinkButton href={`/rdv/new?contact=${c.id}`} size="sm" variant="secondary" className="flex-1">
                    <CalendarPlus className="h-4 w-4" /> Planifier
                  </LinkButton>
                </div>
              </Card>
            ))}

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
                  <div className="flex items-center gap-1">
                    {due.length > MAX_DUE && (
                      <Link href="/contacts" className="text-sm font-medium text-brand-600 dark:text-brand-300">
                        Voir tout ({due.length})
                      </Link>
                    )}
                    <button
                      type="button"
                      onClick={() => setSeeSoonOpen(true)}
                      aria-label="Ajouter quelqu'un à voir bientôt"
                      title="Ajouter quelqu'un à voir bientôt"
                      className="flex h-8 w-8 items-center justify-center rounded-full text-brand-600 hover:bg-brand-50 active:scale-95 dark:text-brand-300 dark:hover:bg-gray-800"
                    >
                      <Plus className="h-5 w-5" strokeWidth={2.5} />
                    </button>
                  </div>
                }
              >
                À recontacter
              </SectionTitle>
              {due.length === 0 ? (
                <Card className="border-emerald-200 bg-emerald-50 dark:border-emerald-900/60 dark:bg-emerald-900/20">
                  <p className="font-semibold text-emerald-900 dark:text-emerald-100">Tout est à jour 🎉</p>
                  <p className="mt-0.5 text-sm text-emerald-800/80 dark:text-emerald-200/80">
                    Personne à recontacter pour l&apos;instant. Envie de voir quelqu&apos;un quand même ? Ajoutez-le avec le bouton +.
                  </p>
                </Card>
              ) : (
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {due.slice(0, MAX_DUE).map(({ c, info }) => (
                      <div key={c.id}>
                        <ContactRow
                          contact={c}
                          right={
                            c.see_soon ? (
                              <span className="inline-flex items-center gap-1 whitespace-nowrap rounded-full bg-violet-100 px-2.5 py-1 text-xs font-semibold text-violet-800 dark:bg-violet-900/40 dark:text-violet-200">
                                <Star className="h-3 w-3" fill="currentColor" /> Bientôt
                              </span>
                            ) : (
                              <DueBadge contact={c} short />
                            )
                          }
                        />
                        <div className="flex gap-2 px-4 pb-3">
                          <LinkButton href={`/rdv/new?contact=${c.id}`} size="sm" className="flex-1">
                            <CalendarPlus className="h-4 w-4" /> Planifier
                          </LinkButton>
                          <Button size="sm" variant="secondary" className="flex-1" onClick={() => setSeenContact(c)}>
                            <Check className="h-4 w-4" /> Vu
                          </Button>
                          {c.see_soon && info.kind === "ok" ? (
                            <Button size="sm" variant="secondary" className="flex-1" onClick={() => removeSeeSoon(c)}>
                              <X className="h-4 w-4" /> Retirer
                            </Button>
                          ) : (
                            <Button size="sm" variant="secondary" className="flex-1" onClick={() => setSnoozeContact(c)}>
                              <Clock className="h-4 w-4" /> Reporter
                            </Button>
                          )}
                        </div>
                      </div>
                    ))}
                  </RowList>
                </Card>
              )}
            </section>

            {/* Anniversaires à venir (7 jours) */}
            {birthdaysSoon.length > 0 && (
              <section>
                <SectionTitle>Anniversaires cette semaine</SectionTitle>
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {birthdaysSoon.map(({ c, b }) => (
                      <Link key={c.id} href={`/contacts/${c.id}`} className="flex items-center gap-3 px-4 py-3 active:bg-gray-100 dark:active:bg-gray-800">
                        <Cake className="h-5 w-5 shrink-0 text-pink-500" />
                        <span className="min-w-0 flex-1 truncate text-[15px] font-medium text-gray-900 dark:text-gray-100">{c.name}</span>
                        <span className="shrink-0 text-sm text-gray-500 dark:text-gray-400">
                          {b.days === 1 ? "demain" : `dans ${b.days} jours`}
                          {b.age > 0 && b.age < 120 ? ` · ${b.age} ans` : ""}
                        </span>
                      </Link>
                    ))}
                  </RowList>
                </Card>
              </section>
            )}

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
      <SeeSoonSheet contacts={notInList} open={seeSoonOpen} onClose={() => setSeeSoonOpen(false)} onDone={() => reload()} />
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
