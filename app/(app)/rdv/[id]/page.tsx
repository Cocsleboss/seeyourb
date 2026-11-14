"use client";

import { CalendarPlus, Check, ChevronRight, Clock, Hourglass, MapPin, Pencil, Send, StickyNote, Trash2, Users, X } from "lucide-react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { PhotoGrid } from "@/components/PhotoGrid";
import { PhotoPicker } from "@/components/PhotoPicker";
import { rdvTitle } from "@/components/rdv/RdvRow";
import { RdvStatusActions } from "@/components/rdv/RdvStatusActions";
import {
  Avatar,
  Button,
  Card,
  ConfirmSheet,
  EmptyState,
  LinkButton,
  Page,
  PageLoader,
  RowList,
  SectionTitle,
  StatusPill,
  TopBar,
  buttonClasses,
  useToast,
} from "@/components/ui";
import {
  addPhoto,
  cancelRdvInvite,
  deletePhoto,
  deleteRdv,
  getRdv,
  listFriends,
  listInvitesForRdv,
  listSharedPhotosForRdv,
  sendRdvInvite,
} from "@/lib/data";
import { useSession } from "@/lib/session";
import type { Friend, Photo, RdvInvitation } from "@/lib/types";
import { capitalize, dayKey, formatDateLong, formatTime, relativeDayLabel } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";

export default function RdvDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { user } = useSession();
  const { data, loading, error, reload } = useAsyncData(async () => {
    const r = await getRdv(id);
    if (!r) return null;
    // Le partage est un "plus" : s'il échoue, la fiche du rendez-vous s'affiche quand même.
    const [invites, shared, friends] = await Promise.all([
      listInvitesForRdv(id).catch(() => [] as RdvInvitation[]),
      r.share_id ? listSharedPhotosForRdv(id).catch(() => [] as Photo[]) : Promise.resolve([] as Photo[]),
      listFriends().catch(() => [] as Friend[]),
    ]);
    return { rdv: r, invites, shared, friends };
  }, [id]);
  const rdv = data?.rdv ?? null;
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [uploading, setUploading] = useState(0);
  const [inviteBusy, setInviteBusy] = useState<string | null>(null);

  const photos = useMemo(
    () => [...(data?.rdv.photos ?? []), ...(data?.shared ?? [])].sort((a, b) => (a.created_at < b.created_at ? 1 : -1)),
    [data]
  );

  if (loading && !rdv) {
    return (
      <>
        <TopBar title="Rendez-vous" back />
        <PageLoader />
      </>
    );
  }

  if (!rdv) {
    return (
      <>
        <TopBar title="Rendez-vous" back />
        <Page>
          <EmptyState
            title="Rendez-vous introuvable"
            description={error ?? "Il a peut-être été supprimé."}
            action={<LinkButton href="/">Retour à l&apos;accueil</LinkButton>}
          />
        </Page>
      </>
    );
  }

  const at = new Date(rdv.appointment_at);
  const isPastUnconfirmed = rdv.status === "planifie" && at.getTime() < Date.now() - 30 * 60_000;

  // Participants associés à un ami SeeU (ami toujours accepté) → on peut leur envoyer le rendez-vous
  const friendIds = new Set((data?.friends ?? []).filter((f) => f.status === "accepted").map((f) => f.user_id));
  const shareable = rdv.contacts.filter((c) => c.linked_user_id && friendIds.has(c.linked_user_id));
  const invites = data?.invites ?? [];
  const isShared = Boolean(rdv.share_id) && invites.some((i) => i.status === "accepted");

  const invite = async (friendUserId: string, name: string) => {
    setInviteBusy(friendUserId);
    try {
      await sendRdvInvite(id, friendUserId);
      toast.success(`Invitation envoyée à ${name}`);
      reload();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Envoi impossible");
    } finally {
      setInviteBusy(null);
    }
  };

  const cancelInvite = async (inv: RdvInvitation) => {
    setInviteBusy(inv.to_user);
    try {
      await cancelRdvInvite(inv.id);
      toast.info("Invitation annulée");
      reload();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Action impossible");
    } finally {
      setInviteBusy(null);
    }
  };

  const addPhotos = async (files: File[]) => {
    for (const file of files) {
      setUploading((n) => n + 1);
      try {
        await addPhoto(file, { rdvId: id });
      } catch (e) {
        toast.error(e instanceof Error ? e.message : "Envoi impossible");
      } finally {
        setUploading((n) => n - 1);
      }
    }
    reload();
  };

  return (
    <>
      <TopBar
        title={rdvTitle(rdv)}
        back
        right={
          <Link
            href={`/rdv/${id}/edit`}
            aria-label="Modifier"
            className="flex h-10 w-10 items-center justify-center rounded-full text-brand-600 hover:bg-gray-100 dark:text-brand-300 dark:hover:bg-gray-800"
          >
            <Pencil className="h-5 w-5" />
          </Link>
        }
      />
      <Page className="space-y-5">
        {isPastUnconfirmed && (
          <Card className="space-y-3 border-amber-200 bg-amber-50 dark:border-amber-900/60 dark:bg-amber-900/20">
            <div>
              <p className="font-semibold text-amber-900 dark:text-amber-100">Ce rendez-vous a-t-il eu lieu ?</p>
              <p className="mt-0.5 text-sm text-amber-800/80 dark:text-amber-200/80">
                Confirmez-le pour mettre à jour la date de dernière rencontre des participants.
              </p>
            </div>
            <RdvStatusActions rdv={rdv} onChanged={() => reload()} />
          </Card>
        )}

        <Card className="space-y-3">
          <div className="flex items-center justify-between">
            <StatusPill status={rdv.status} />
            <span className="text-sm text-gray-500 dark:text-gray-400">{relativeDayLabel(at)}</span>
          </div>
          <div>
            <p className="text-xl font-bold text-gray-900 dark:text-gray-100">{capitalize(formatDateLong(dayKey(at)))}</p>
            <p className="mt-0.5 flex items-center gap-1.5 text-gray-600 dark:text-gray-300">
              <Clock className="h-4 w-4" /> {formatTime(at)}
            </p>
          </div>
          {rdv.location && (
            <a
              href={`https://maps.apple.com/?q=${encodeURIComponent(rdv.location)}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-brand-600 dark:text-brand-300"
            >
              <MapPin className="h-4 w-4 shrink-0" /> <span className="underline-offset-2 hover:underline">{rdv.location}</span>
            </a>
          )}
          {rdv.notes && (
            <p className="flex items-start gap-1.5 whitespace-pre-line text-sm text-gray-700 dark:text-gray-200">
              <StickyNote className="mt-0.5 h-4 w-4 shrink-0 text-gray-400" /> <span>{rdv.notes}</span>
            </p>
          )}
          {isShared && (
            <p className="flex items-start gap-1.5 rounded-xl bg-brand-50 px-3 py-2 text-xs text-brand-800 dark:bg-brand-900/20 dark:text-brand-200">
              <Users className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              <span>Rendez-vous partagé : date, lieu, titre et statut sont les mêmes pour tous. Vos notes restent privées.</span>
            </p>
          )}
        </Card>

        <section>
          <SectionTitle>Participants</SectionTitle>
          <Card className="overflow-hidden p-0">
            {rdv.contacts.length === 0 ? (
              <p className="px-4 py-4 text-sm text-gray-500">Aucun participant.</p>
            ) : (
              <RowList>
                {rdv.contacts.map((c) => (
                  <Link key={c.id} href={`/contacts/${c.id}`} className="flex items-center gap-3 px-4 py-3 active:bg-gray-100 dark:active:bg-gray-800">
                    <Avatar name={c.name} path={c.photo_path} size={40} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-gray-900 dark:text-gray-100">{c.name}</span>
                      {c.category && <span className="block text-xs text-gray-500">{c.category}</span>}
                    </span>
                    <ChevronRight className="h-4 w-4 text-gray-300" />
                  </Link>
                ))}
              </RowList>
            )}
          </Card>
        </section>

        {/* Partage avec les amis SeeU */}
        {(shareable.length > 0 || invites.length > 0) && (
          <section>
            <SectionTitle>Partage</SectionTitle>
            <Card className="overflow-hidden p-0">
              <RowList>
                {shareable.map((c) => {
                  const friendId = c.linked_user_id as string;
                  const sentInv = invites.find((i) => i.rdv_id === id && i.to_user === friendId);
                  const received = invites.find((i) => i.to_rdv_id === id && i.from_user === friendId);
                  const busy = inviteBusy === friendId;
                  return (
                    <div key={c.id} className="flex items-center gap-3 px-4 py-3">
                      <Avatar name={c.name} path={c.photo_path} size={40} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate font-medium text-gray-900 dark:text-gray-100">{c.name}</p>
                        <p className="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400">
                          {received ? (
                            <>
                              <Check className="h-3.5 w-3.5 text-emerald-600" /> Vous a proposé ce rendez-vous
                            </>
                          ) : sentInv?.status === "accepted" ? (
                            <>
                              <Check className="h-3.5 w-3.5 text-emerald-600" /> A accepté · rendez-vous partagé
                            </>
                          ) : sentInv?.status === "pending" ? (
                            <>
                              <Hourglass className="h-3.5 w-3.5 text-amber-600" /> Invitation envoyée · en attente
                            </>
                          ) : sentInv?.status === "declined" ? (
                            <>
                              <X className="h-3.5 w-3.5 text-red-600" /> A décliné l&apos;invitation
                            </>
                          ) : (
                            "Ami SeeU · pas encore invité"
                          )}
                        </p>
                      </div>
                      {!received && rdv.status !== "annule" && (!sentInv || sentInv.status === "declined") && (
                        <Button size="sm" loading={busy} disabled={inviteBusy !== null} onClick={() => invite(friendId, c.name)}>
                          <Send className="h-4 w-4" /> {sentInv ? "Renvoyer" : "Envoyer"}
                        </Button>
                      )}
                      {sentInv?.status === "pending" && (
                        <Button size="sm" variant="ghost" loading={busy} disabled={inviteBusy !== null} onClick={() => cancelInvite(sentInv)}>
                          Annuler
                        </Button>
                      )}
                    </div>
                  );
                })}
              </RowList>
            </Card>
            <p className="mt-1.5 px-1 text-xs text-gray-500 dark:text-gray-400">
              Si votre ami accepte, vous avez tous les deux le rendez-vous. Une fois validé, chacun voit sa période repartir de zéro, et les photos sont communes.
            </p>
          </section>
        )}

        <section className="space-y-2">
          {!isPastUnconfirmed && <RdvStatusActions rdv={rdv} onChanged={() => reload()} />}
          {rdv.status === "planifie" && (
            <a href={`/api/ics/${id}`} className={buttonClasses({ variant: "outline", full: true })}>
              <CalendarPlus className="h-5 w-5" /> Ajouter au calendrier
            </a>
          )}
        </section>

        <section>
          <SectionTitle
            action={
              <PhotoPicker multiple variant="ghost" className="h-9 px-2 text-sm" onPick={addPhotos} disabled={uploading > 0}>
                Ajouter
              </PhotoPicker>
            }
          >
            {isShared ? "Photos partagées" : "Photos"}
          </SectionTitle>
          {photos.length === 0 && uploading === 0 ? (
            <p className="text-sm text-gray-500 dark:text-gray-400">
              {isShared ? "Ajoutez des photos de ce moment : tous les participants les verront." : "Ajoutez des photos de ce moment."}
            </p>
          ) : (
            <PhotoGrid
              photos={photos}
              pendingCount={uploading}
              canDelete={(p) => p.user_id === user.id}
              onDelete={async (p) => {
                await deletePhoto(p);
                toast.success("Photo supprimée");
                reload();
              }}
            />
          )}
        </section>

        <div className="pt-2">
          <Button variant="danger" full onClick={() => setConfirmDelete(true)}>
            <Trash2 className="h-5 w-5" /> Supprimer le rendez-vous
          </Button>
        </div>
      </Page>

      <ConfirmSheet
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        danger
        title="Supprimer ce rendez-vous ?"
        message={
          isShared
            ? "Il sera supprimé chez vous uniquement (vos amis gardent le leur), et vos photos disparaîtront de la galerie commune. Cette action est définitive."
            : "Les photos associées seront supprimées. Cette action est définitive."
        }
        confirmLabel="Supprimer"
        onConfirm={async () => {
          await deleteRdv(rdv);
          toast.success("Rendez-vous supprimé");
          router.replace("/");
        }}
      />
    </>
  );
}
