"use client";

import { CalendarPlus, Check, ChevronRight, Hand, Link2, Link2Off, Search, Share2, Trash2, UserPlus, Users, X } from "lucide-react";
import { useSearchParams } from "next/navigation";
import { Suspense, useEffect, useMemo, useState, type FormEvent } from "react";
import { IncomingInvites } from "@/components/social/IncomingInvites";
import {
  Avatar,
  Button,
  Card,
  ConfirmSheet,
  EmptyState,
  Input,
  LinkButton,
  ListSkeleton,
  Page,
  PageLoader,
  RowList,
  SectionTitle,
  Sheet,
  TopBar,
  useToast,
} from "@/components/ui";
import {
  linkFriendToContact,
  listContacts,
  listFriends,
  listIncomingInvites,
  removeFriend,
  respondFriendRequest,
  searchUsers,
  sendFriendRequest,
  sendWave,
  unlinkFriend,
} from "@/lib/data";
import { useAsyncData } from "@/lib/hooks";
import { matchesQuery, normalizeText } from "@/lib/text";
import { useSession } from "@/lib/session";
import type { Contact, Friend, IncomingInvite, UserSearchResult } from "@/lib/types";
import { handle, normalizeUsername } from "@/lib/username";

export default function FriendsPage() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Friends />
    </Suspense>
  );
}

const RELATION_NOTE: Record<UserSearchResult["relation"], string | null> = {
  none: null,
  friends: "Déjà dans vos amis",
  sent: "Demande envoyée",
  received: "Vous a envoyé une demande",
};

/**
 * Amis SeeU : chercher quelqu'un par son nom d'utilisateur (@...), répondre aux demandes,
 * associer chaque ami à un contact (existant ou nouveau), répondre aux invitations à un rendez-vous.
 */
function Friends() {
  const toast = useToast();
  const { profile } = useSession();
  const params = useSearchParams();
  const { data, loading, error, reload } = useAsyncData(
    () => Promise.all([listFriends(), listContacts(), listIncomingInvites().catch(() => [] as IncomingInvite[])]),
    []
  );
  // lien de partage « /friends?add=nom » : la recherche est pré-remplie
  const [query, setQuery] = useState(() => normalizeUsername(params.get("add") ?? ""));
  const [results, setResults] = useState<UserSearchResult[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [sending, setSending] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [linking, setLinking] = useState<Friend | null>(null);
  const [selected, setSelected] = useState<Friend | null>(null);
  const [removing, setRemoving] = useState<Friend | null>(null);
  const [waving, setWaving] = useState(false);

  const friends = useMemo(() => data?.[0] ?? [], [data]);
  const contacts = useMemo(() => data?.[1] ?? [], [data]);
  const invites = useMemo(() => data?.[2] ?? [], [data]);

  const accepted = friends.filter((f) => f.status === "accepted");
  const received = friends.filter((f) => f.status === "pending" && f.incoming);
  const sent = friends.filter((f) => f.status === "pending" && !f.incoming);
  const contactOf = (f: Friend) => contacts.find((c) => c.linked_user_id === f.user_id) ?? null;

  // recherche au fil de la frappe (début du nom d'utilisateur, 2 caractères minimum)
  useEffect(() => {
    if (query.length < 2) {
      setResults(null);
      setSearching(false);
      return;
    }
    let alive = true;
    setSearching(true);
    const t = setTimeout(() => {
      searchUsers(query)
        .then((r) => alive && setResults(r))
        .catch((err) => {
          if (!alive) return;
          setResults([]);
          toast.error(err instanceof Error ? err.message : "Recherche impossible");
        })
        .finally(() => alive && setSearching(false));
    }, 300);
    return () => {
      alive = false;
      clearTimeout(t);
    };
  }, [query]); // eslint-disable-line react-hooks/exhaustive-deps

  const add = async (u: UserSearchResult) => {
    setSending(u.user_id);
    try {
      const res = await sendFriendRequest(u.username);
      const who = res.display_name ?? handle(u.username);
      if (res.status === "not_found") toast.error("Ce compte n'existe plus.");
      else if (res.status === "already_friends") toast.info(`${who} fait déjà partie de vos amis.`);
      else if (res.status === "already_sent") toast.info("Demande déjà envoyée, en attente de sa réponse.");
      else if (res.status === "accepted") toast.success(`${who} vous avait déjà invité : vous êtes maintenant amis !`);
      else if (res.status === "sent") toast.success(`Demande envoyée à ${who}`);
      const relation = res.status === "accepted" || res.status === "already_friends" ? "friends" : "sent";
      setResults((list) => list?.map((x) => (x.user_id === u.user_id ? { ...x, relation } : x)) ?? null);
      reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Envoi impossible");
    } finally {
      setSending(null);
    }
  };

  const wave = async (f: Friend) => {
    setWaving(true);
    try {
      await sendWave(f.user_id);
      toast.success(`${f.display_name} sait que vous aimeriez vous voir 👋`);
      setSelected(null);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Envoi impossible");
    } finally {
      setWaving(false);
    }
  };

  const shareMe = async () => {
    if (!profile?.username) return;
    const url = `${window.location.origin}/friends?add=${encodeURIComponent(profile.username)}`;
    const text = `Ajoute-moi sur SeeU : ${handle(profile.username)}`;
    try {
      if (navigator.share) await navigator.share({ title: "SeeU", text, url });
      else {
        await navigator.clipboard.writeText(`${text} ${url}`);
        toast.success("Lien copié");
      }
    } catch {
      /* partage annulé */
    }
  };

  const shareApp = async () => {
    const url = window.location.origin;
    const text = "Rejoins-moi sur SeeU, l'app pour ne plus perdre de vue les gens qu'on aime :";
    try {
      if (navigator.share) await navigator.share({ title: "SeeU", text, url });
      else {
        await navigator.clipboard.writeText(`${text} ${url}`);
        toast.success("Lien copié");
      }
    } catch {
      /* partage annulé */
    }
  };

  const respond = async (f: Friend, accept: boolean) => {
    setBusy(f.friendship_id);
    try {
      await respondFriendRequest(f.friendship_id, accept);
      if (accept) {
        toast.success(`Vous êtes maintenant amis avec ${f.display_name}`);
        setLinking({ ...f, status: "accepted" });
      } else toast.info("Demande refusée");
      reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Action impossible");
    } finally {
      setBusy(null);
    }
  };

  const cancel = async (f: Friend) => {
    setBusy(f.friendship_id);
    try {
      await removeFriend(f.friendship_id);
      toast.info("Demande annulée");
      reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Action impossible");
    } finally {
      setBusy(null);
    }
  };

  const selectedContact = selected ? contactOf(selected) : null;

  return (
    <>
      <TopBar title="Amis" subtitle="Partagez rendez-vous et photos avec d'autres utilisateurs" />
      <Page className="space-y-5">
        {/* Chercher par nom d'utilisateur */}
        <Card className="space-y-3">
          <div>
            <h2 className="font-semibold text-gray-900 dark:text-gray-100">Ajouter un ami</h2>
            <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">Cherchez-le par son nom d&apos;utilisateur SeeU.</p>
          </div>
          <form onSubmit={(e: FormEvent) => e.preventDefault()} role="search">
            <div className="relative">
              <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[16px] font-semibold text-gray-400">@</span>
              <Input
                type="search"
                autoCapitalize="none"
                autoCorrect="off"
                spellCheck={false}
                value={query}
                onChange={(e) => setQuery(normalizeUsername(e.target.value))}
                placeholder="nom.utilisateur"
                className="pl-9"
                aria-label="Nom d'utilisateur de votre ami"
              />
            </div>
          </form>
          {query.length >= 2 && results !== null && (
            <ul className="divide-y divide-gray-100 dark:divide-gray-800">
              {results.map((u) => (
                <li key={u.user_id} className="flex items-center gap-3 py-2.5">
                  <Avatar name={u.display_name} size={40} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[15px] font-semibold text-gray-900 dark:text-gray-100">{u.display_name}</p>
                    <p className="truncate text-xs text-gray-500 dark:text-gray-400">
                      {handle(u.username)}
                      {RELATION_NOTE[u.relation] ? ` · ${RELATION_NOTE[u.relation]}` : ""}
                    </p>
                  </div>
                  {u.relation === "none" && (
                    <Button size="sm" loading={sending === u.user_id} disabled={sending !== null} onClick={() => add(u)}>
                      <UserPlus className="h-4 w-4" /> Ajouter
                    </Button>
                  )}
                  {u.relation === "received" && (
                    <Button size="sm" loading={sending === u.user_id} disabled={sending !== null} onClick={() => add(u)}>
                      <Check className="h-4 w-4" /> Accepter
                    </Button>
                  )}
                </li>
              ))}
              {results.length === 0 && !searching && (
                <li className="space-y-2 py-3 text-sm text-gray-600 dark:text-gray-300">
                  <p>
                    Aucun compte ne commence par <span className="font-semibold">{handle(query)}</span>. Vérifiez l&apos;orthographe, ou invitez cette
                    personne à créer son compte.
                  </p>
                  <Button size="sm" variant="secondary" onClick={shareApp}>
                    <Share2 className="h-4 w-4" /> Envoyer le lien de l&apos;app
                  </Button>
                </li>
              )}
            </ul>
          )}
          {profile?.username && (
            <div className="flex items-center justify-between gap-3 rounded-xl bg-gray-50 px-3 py-2.5 dark:bg-gray-800/60">
              <p className="min-w-0 text-sm text-gray-600 dark:text-gray-300">
                Votre nom d&apos;utilisateur : <span className="font-semibold text-gray-900 dark:text-gray-100">{handle(profile.username)}</span>
              </p>
              <Button size="sm" variant="secondary" onClick={shareMe}>
                <Share2 className="h-4 w-4" /> Partager
              </Button>
            </div>
          )}
        </Card>

        {loading && !data ? (
          <ListSkeleton rows={3} />
        ) : error && !data ? (
          <Card className="space-y-3 border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/20">
            <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
            <Button variant="secondary" onClick={() => reload(false)}>
              Réessayer
            </Button>
          </Card>
        ) : (
          <>
            {invites.length > 0 && (
              <section>
                <SectionTitle>Invitations à un rendez-vous</SectionTitle>
                <IncomingInvites invites={invites} onChanged={() => reload()} />
              </section>
            )}

            {received.length > 0 && (
              <section>
                <SectionTitle>Demandes reçues</SectionTitle>
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {received.map((f) => (
                      <div key={f.friendship_id} className="space-y-2 px-4 py-3">
                        <FriendIdentity friend={f} />
                        <div className="flex gap-2">
                          <Button size="sm" variant="secondary" className="flex-1" disabled={busy !== null} onClick={() => respond(f, false)}>
                            <X className="h-4 w-4" /> Refuser
                          </Button>
                          <Button size="sm" className="flex-1" disabled={busy !== null} loading={busy === f.friendship_id} onClick={() => respond(f, true)}>
                            <Check className="h-4 w-4" /> Accepter
                          </Button>
                        </div>
                      </div>
                    ))}
                  </RowList>
                </Card>
              </section>
            )}

            <section>
              <SectionTitle>Mes amis{accepted.length ? ` (${accepted.length})` : ""}</SectionTitle>
              {accepted.length === 0 ? (
                <Card>
                  <EmptyState
                    className="py-4"
                    icon={<Users className="h-6 w-6" />}
                    title="Pas encore d'ami SeeU"
                    description="Ajoutez un ami par son nom d'utilisateur : vous pourrez lui proposer vos rendez-vous. S'il accepte, vous l'aurez tous les deux, vos périodes se remettront à zéro chacun de votre côté et vous partagerez les photos."
                  />
                </Card>
              ) : (
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {accepted.map((f) => {
                      const c = contactOf(f);
                      return (
                        <div key={f.friendship_id}>
                          <button
                            type="button"
                            onClick={() => setSelected(f)}
                            className="flex w-full items-center gap-3 px-4 py-3 text-left transition active:bg-gray-100 dark:active:bg-gray-800"
                          >
                            <Avatar name={c?.name ?? f.display_name} path={c?.photo_path} size={46} />
                            <span className="min-w-0 flex-1">
                              <span className="block truncate text-[15px] font-semibold text-gray-900 dark:text-gray-100">{f.display_name}</span>
                              <span className="block truncate text-xs text-gray-500 dark:text-gray-400">
                                {[handle(f.username), c ? `Associé au contact ${c.name}` : null].filter(Boolean).join(" · ") || f.email}
                              </span>
                            </span>
                            <ChevronRight className="h-4 w-4 shrink-0 text-gray-300 dark:text-gray-600" />
                          </button>
                          {!c && (
                            <div className="px-4 pb-3">
                              <Button size="sm" full onClick={() => setLinking(f)}>
                                <Link2 className="h-4 w-4" /> Associer à un contact
                              </Button>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </RowList>
                </Card>
              )}
            </section>

            {sent.length > 0 && (
              <section>
                <SectionTitle>Demandes envoyées</SectionTitle>
                <Card className="overflow-hidden p-0">
                  <RowList>
                    {sent.map((f) => (
                      <div key={f.friendship_id} className="flex items-center gap-3 px-4 py-3">
                        <div className="min-w-0 flex-1">
                          <FriendIdentity friend={f} note="En attente de sa réponse" />
                        </div>
                        <Button size="sm" variant="ghost" disabled={busy !== null} onClick={() => cancel(f)}>
                          Annuler
                        </Button>
                      </div>
                    ))}
                  </RowList>
                </Card>
              </section>
            )}
          </>
        )}
      </Page>

      {/* Actions sur un ami */}
      <Sheet open={selected !== null} onClose={() => setSelected(null)} title={selected?.display_name}>
        {selected && (
          <div className="space-y-2">
            <p className="break-all text-sm text-gray-500 dark:text-gray-400">{[handle(selected.username), selected.email].filter(Boolean).join(" · ")}</p>
            <Button variant="secondary" full loading={waving} onClick={() => wave(selected)}>
              <Hand className="h-5 w-5" /> Envie de se voir
            </Button>
            <p className="pb-1 text-xs text-gray-500 dark:text-gray-400">
              {selected.display_name} reçoit une notification et vous retrouve dans sa liste « À voir bientôt ». Une fois par jour.
            </p>
            {selectedContact ? (
              <>
                <LinkButton href={`/rdv/new?contact=${selectedContact.id}`} full>
                  <CalendarPlus className="h-5 w-5" /> Proposer un rendez-vous
                </LinkButton>
                <LinkButton href={`/contacts/${selectedContact.id}`} variant="secondary" full>
                  Voir le contact {selectedContact.name}
                </LinkButton>
                <Button
                  variant="secondary"
                  full
                  onClick={() => {
                    setLinking(selected);
                    setSelected(null);
                  }}
                >
                  <Link2 className="h-5 w-5" /> Associer à un autre contact
                </Button>
                <Button
                  variant="secondary"
                  full
                  onClick={async () => {
                    try {
                      await unlinkFriend(selected.user_id);
                      toast.info("Contact dissocié");
                      setSelected(null);
                      reload();
                    } catch (err) {
                      toast.error(err instanceof Error ? err.message : "Action impossible");
                    }
                  }}
                >
                  <Link2Off className="h-5 w-5" /> Dissocier du contact
                </Button>
              </>
            ) : (
              <Button
                full
                onClick={() => {
                  setLinking(selected);
                  setSelected(null);
                }}
              >
                <Link2 className="h-5 w-5" /> Associer à un contact
              </Button>
            )}
            <Button
              variant="danger"
              full
              onClick={() => {
                setRemoving(selected);
                setSelected(null);
              }}
            >
              <Trash2 className="h-5 w-5" /> Retirer de mes amis
            </Button>
          </div>
        )}
      </Sheet>

      <LinkContactSheet
        friend={linking}
        contacts={contacts}
        onClose={() => setLinking(null)}
        onLinked={() => {
          setLinking(null);
          reload();
        }}
      />

      <ConfirmSheet
        open={removing !== null}
        onClose={() => setRemoving(null)}
        danger
        title={`Retirer ${removing?.display_name ?? "cet ami"} ?`}
        message="Vos contacts et rendez-vous existants sont conservés, mais vous ne pourrez plus vous envoyer d'invitations. Les invitations en attente sont annulées."
        confirmLabel="Retirer"
        onConfirm={async () => {
          if (!removing) return;
          await removeFriend(removing.friendship_id);
          toast.info("Ami retiré");
          setRemoving(null);
          reload();
        }}
      />
    </>
  );
}

function FriendIdentity({ friend, note }: { friend: Friend; note?: string }) {
  return (
    <div className="flex items-center gap-3">
      <Avatar name={friend.display_name} size={42} />
      <div className="min-w-0">
        <p className="truncate text-[15px] font-semibold text-gray-900 dark:text-gray-100">{friend.display_name}</p>
        <p className="truncate text-xs text-gray-500 dark:text-gray-400">{[handle(friend.username), note].filter(Boolean).join(" · ")}</p>
      </div>
    </div>
  );
}

/** Associe un ami à un contact existant (suggestions par email / nom) ou propose d'en créer un. */
function LinkContactSheet({
  friend,
  contacts,
  onClose,
  onLinked,
}: {
  friend: Friend | null;
  contacts: Contact[];
  onClose: () => void;
  onLinked: () => void;
}) {
  const toast = useToast();
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState<string | null>(null);

  const sorted = useMemo(() => {
    if (!friend) return [];
    const mail = friend.email?.toLowerCase() ?? "";
    const first = normalizeText(friend.display_name).split(/\s+/)[0] ?? "";
    const score = (c: Contact) =>
      (mail && c.email?.toLowerCase() === mail ? 2 : 0) + (first.length >= 2 && normalizeText(c.name).includes(first) ? 1 : 0);
    return contacts
      .filter((c) => !c.linked_user_id || c.linked_user_id === friend.user_id)
      .map((c) => ({ c, s: score(c) }))
      .sort((a, b) => b.s - a.s || a.c.name.localeCompare(b.c.name, "fr"));
  }, [friend, contacts]);

  const visible = sorted.filter(({ c }) => matchesQuery(c.name, query) || matchesQuery(c.email, query));

  const link = async (c: Contact) => {
    if (!friend) return;
    setBusy(c.id);
    try {
      await linkFriendToContact(friend.user_id, c.id);
      toast.success(`${friend.display_name} est associé au contact ${c.name}`);
      setQuery("");
      onLinked();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Association impossible");
    } finally {
      setBusy(null);
    }
  };

  const newHref = friend
    ? `/contacts/new?friend=${friend.user_id}&name=${encodeURIComponent(friend.display_name)}${friend.email ? `&email=${encodeURIComponent(friend.email)}` : ""}`
    : "/contacts/new";

  return (
    <Sheet open={friend !== null} onClose={onClose} title={friend ? `Associer ${friend.display_name}` : undefined}>
      <p className="text-sm text-gray-600 dark:text-gray-300">
        Quel contact correspond à cet ami ? C&apos;est sa période qui sera remise à zéro quand vous validerez un rendez-vous ensemble.
      </p>
      <LinkButton href={newHref} variant="secondary" full className="mt-3">
        <UserPlus className="h-5 w-5" /> Créer un nouveau contact
      </LinkButton>
      {contacts.length > 0 && (
        <>
          <div className="relative mt-3">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
            <Input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Rechercher dans mes contacts…" className="pl-11" aria-label="Rechercher un contact" />
          </div>
          <ul className="mt-2 min-h-[25dvh] divide-y divide-gray-100 dark:divide-gray-800">
            {visible.length === 0 && <li className="py-6 text-center text-sm text-gray-500">Aucun contact ne correspond.</li>}
            {visible.map(({ c, s }) => (
              <li key={c.id}>
                <button
                  type="button"
                  disabled={busy !== null}
                  onClick={() => link(c)}
                  className="flex w-full items-center gap-3 px-1 py-2.5 text-left transition active:bg-gray-100 disabled:opacity-50 dark:active:bg-gray-800"
                >
                  <Avatar name={c.name} path={c.photo_path} size={38} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[15px] font-medium text-gray-900 dark:text-gray-100">{c.name}</span>
                    {(c.email || c.category) && <span className="block truncate text-xs text-gray-500">{c.email ?? c.category}</span>}
                  </span>
                  {s > 0 && !query && (
                    <span className="shrink-0 rounded-full bg-brand-100 px-2 py-0.5 text-[11px] font-semibold text-brand-800 dark:bg-brand-900/40 dark:text-brand-100">
                      Suggéré
                    </span>
                  )}
                  {c.linked_user_id === friend?.user_id && <Check className="h-4 w-4 shrink-0 text-emerald-600" />}
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </Sheet>
  );
}
