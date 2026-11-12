"use client";

import { CalendarPlus, ChevronRight, Clock, MapPin, Pencil, StickyNote, Trash2 } from "lucide-react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
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
import { addPhoto, deletePhoto, deleteRdv, getRdv } from "@/lib/data";
import { capitalize, dayKey, formatDateLong, formatTime, relativeDayLabel } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";

export default function RdvDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { data: rdv, loading, error, reload, setData } = useAsyncData(() => getRdv(id), [id]);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [uploading, setUploading] = useState(0);

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
            <RdvStatusActions rdv={rdv} onChanged={setData} />
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

        <section className="space-y-2">
          {!isPastUnconfirmed && <RdvStatusActions rdv={rdv} onChanged={setData} />}
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
            Photos
          </SectionTitle>
          {rdv.photos.length === 0 && uploading === 0 ? (
            <p className="text-sm text-gray-500 dark:text-gray-400">Ajoutez des photos de ce moment.</p>
          ) : (
            <PhotoGrid
              photos={rdv.photos}
              pendingCount={uploading}
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
        message="Les photos associées seront supprimées. Cette action est définitive."
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
