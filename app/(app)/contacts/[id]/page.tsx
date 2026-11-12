"use client";

import { Cake, CalendarPlus, Check, Clock, Mail, Pencil, Phone, StickyNote, Trash2 } from "lucide-react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import { MarkSeenSheet } from "@/components/contacts/MarkSeenSheet";
import { SnoozeSheet } from "@/components/contacts/SnoozeSheet";
import { PhotoGrid } from "@/components/PhotoGrid";
import { PhotoPicker } from "@/components/PhotoPicker";
import { RdvRow } from "@/components/rdv/RdvRow";
import {
  Avatar,
  Button,
  Card,
  ConfirmSheet,
  DueBadge,
  EmptyState,
  LinkButton,
  Page,
  PageLoader,
  RowList,
  SectionTitle,
  TopBar,
  useToast,
} from "@/components/ui";
import { addPhoto, deleteContact, deletePhoto, getContact, listPhotosForContact, listRdvForContact } from "@/lib/data";
import { effectiveDueDate, formatDateLong, frequencyLabel, nextBirthday } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";

function birthdayLabel(b: { days: number; age: number }): string {
  const age = b.age > 0 ? ` (${b.age} ans)` : "";
  if (b.days === 0) return `C'est son anniversaire aujourd'hui !${age}`;
  if (b.days === 1) return `Anniversaire demain${age}`;
  return `Anniversaire dans ${b.days} jours${age}`;
}

export default function ContactDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const toast = useToast();
  const { data, loading, error, reload } = useAsyncData(
    () => Promise.all([getContact(id), listRdvForContact(id), listPhotosForContact(id)]),
    [id]
  );
  const [seenOpen, setSeenOpen] = useState(false);
  const [snoozeOpen, setSnoozeOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [uploading, setUploading] = useState(0);

  if (loading && !data) {
    return (
      <>
        <TopBar title="Contact" back="/contacts" />
        <PageLoader />
      </>
    );
  }

  const [contact, rdvs, photos] = data ?? [null, [], []];

  if (!contact) {
    return (
      <>
        <TopBar title="Contact" back="/contacts" />
        <Page>
          <EmptyState
            title="Contact introuvable"
            description={error ?? "Il a peut-être été supprimé."}
            action={<LinkButton href="/contacts">Voir mes contacts</LinkButton>}
          />
        </Page>
      </>
    );
  }

  const now = Date.now();
  const upcoming = rdvs
    .filter((r) => r.status === "planifie" && new Date(r.appointment_at).getTime() >= now)
    .sort((a, b) => (a.appointment_at < b.appointment_at ? -1 : 1));
  const upcomingIds = new Set(upcoming.map((r) => r.id));
  const past = rdvs.filter((r) => !upcomingIds.has(r.id));
  const bday = nextBirthday(contact.birthday);
  const snoozed = Boolean(contact.snooze_until && contact.snooze_until > contact.next_due_date);
  const hasInfo = Boolean(contact.phone || contact.email || contact.notes);

  const addPhotos = async (files: File[]) => {
    for (const file of files) {
      setUploading((n) => n + 1);
      try {
        await addPhoto(file, { contactId: id });
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
        title={contact.name}
        back="/contacts"
        right={
          <Link
            href={`/contacts/${id}/edit`}
            aria-label="Modifier"
            className="flex h-10 w-10 items-center justify-center rounded-full text-brand-600 hover:bg-gray-100 dark:text-brand-300 dark:hover:bg-gray-800"
          >
            <Pencil className="h-5 w-5" />
          </Link>
        }
      />
      <Page className="space-y-5">
        {/* En-tête */}
        <div className="flex flex-col items-center text-center">
          <Avatar name={contact.name} path={contact.photo_path} size={96} className="shadow-md" />
          <h2 className="mt-3 text-2xl font-bold text-gray-900 dark:text-gray-100">{contact.name}</h2>
          {contact.category && (
            <span className="mt-1 rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-medium text-gray-600 dark:bg-gray-800 dark:text-gray-300">
              {contact.category}
            </span>
          )}
          {bday && (bday.days <= 30 || bday.days === 0) && (
            <p className="mt-2 flex items-center gap-1.5 text-sm text-pink-600 dark:text-pink-300">
              <Cake className="h-4 w-4" /> {birthdayLabel(bday)}
            </p>
          )}
        </div>

        {/* Suivi */}
        <Card className="space-y-2">
          <DueBadge contact={contact} />
          <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
            <dt className="text-gray-500 dark:text-gray-400">Dernière rencontre</dt>
            <dd className="font-medium">{formatDateLong(contact.last_meeting_date)}</dd>
            <dt className="text-gray-500 dark:text-gray-400">Prochaine échéance</dt>
            <dd className="font-medium">
              {formatDateLong(effectiveDueDate(contact))}
              {snoozed && <span className="ml-1 text-xs font-normal text-gray-500">(reportée)</span>}
            </dd>
            <dt className="text-gray-500 dark:text-gray-400">Fréquence</dt>
            <dd className="font-medium">{frequencyLabel(contact.frequency_value, contact.frequency_unit)}</dd>
          </dl>
        </Card>

        {/* Actions */}
        <div className="grid grid-cols-2 gap-2">
          <LinkButton href={`/rdv/new?contact=${id}`} className="col-span-2">
            <CalendarPlus className="h-5 w-5" /> Planifier un rendez-vous
          </LinkButton>
          <Button variant="secondary" onClick={() => setSeenOpen(true)}>
            <Check className="h-5 w-5" /> Vu aujourd&apos;hui
          </Button>
          <Button variant="secondary" onClick={() => setSnoozeOpen(true)}>
            <Clock className="h-5 w-5" /> Reporter
          </Button>
        </div>

        {/* Informations */}
        {hasInfo && (
          <section>
            <SectionTitle>Informations</SectionTitle>
            <Card className="space-y-3 text-sm">
              {contact.phone && (
                <a href={`tel:${contact.phone.replace(/\s+/g, "")}`} className="flex items-center gap-3 text-brand-600 dark:text-brand-300">
                  <Phone className="h-5 w-5 shrink-0" /> {contact.phone}
                </a>
              )}
              {contact.email && (
                <a href={`mailto:${contact.email}`} className="flex items-center gap-3 break-all text-brand-600 dark:text-brand-300">
                  <Mail className="h-5 w-5 shrink-0" /> {contact.email}
                </a>
              )}
              {contact.birthday && (
                <p className="flex items-center gap-3 text-gray-700 dark:text-gray-200">
                  <Cake className="h-5 w-5 shrink-0 text-gray-400" /> Né(e) le {formatDateLong(contact.birthday)}
                </p>
              )}
              {contact.notes && (
                <p className="flex items-start gap-3 whitespace-pre-line text-gray-700 dark:text-gray-200">
                  <StickyNote className="mt-0.5 h-5 w-5 shrink-0 text-gray-400" /> <span>{contact.notes}</span>
                </p>
              )}
            </Card>
          </section>
        )}

        {/* Rendez-vous */}
        <section>
          <SectionTitle>Rendez-vous</SectionTitle>
          {rdvs.length === 0 ? (
            <p className="text-sm text-gray-500 dark:text-gray-400">Aucun rendez-vous avec ce contact pour l&apos;instant.</p>
          ) : (
            <div className="space-y-3">
              {upcoming.length > 0 && (
                <div>
                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-500">À venir</p>
                  <Card className="overflow-hidden p-0">
                    <RowList>
                      {upcoming.map((r) => (
                        <RdvRow key={r.id} rdv={r} />
                      ))}
                    </RowList>
                  </Card>
                </div>
              )}
              {past.length > 0 && (
                <div>
                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-gray-500">Passés</p>
                  <Card className="overflow-hidden p-0">
                    <RowList>
                      {past.map((r) => (
                        <RdvRow key={r.id} rdv={r} showStatus />
                      ))}
                    </RowList>
                  </Card>
                </div>
              )}
            </div>
          )}
        </section>

        {/* Galerie */}
        <section>
          <SectionTitle
            action={
              <PhotoPicker multiple variant="ghost" className="h-9 px-2 text-sm" onPick={addPhotos} disabled={uploading > 0}>
                Ajouter
              </PhotoPicker>
            }
          >
            Galerie
          </SectionTitle>
          {photos.length === 0 && uploading === 0 ? (
            <p className="text-sm text-gray-500 dark:text-gray-400">Ajoutez des photos de vos moments partagés.</p>
          ) : (
            <PhotoGrid
              photos={photos}
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
            <Trash2 className="h-5 w-5" /> Supprimer le contact
          </Button>
        </div>
      </Page>

      <MarkSeenSheet contact={contact} open={seenOpen} onClose={() => setSeenOpen(false)} onDone={() => reload()} />
      <SnoozeSheet contact={contact} open={snoozeOpen} onClose={() => setSnoozeOpen(false)} onDone={() => reload()} />
      <ConfirmSheet
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        danger
        title="Supprimer ce contact ?"
        message="Ses rendez-vous et photos seront aussi supprimés. Cette action est définitive."
        confirmLabel="Supprimer"
        onConfirm={async () => {
          await deleteContact(contact);
          toast.success("Contact supprimé");
          router.replace("/contacts");
        }}
      />
    </>
  );
}
