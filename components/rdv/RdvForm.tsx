"use client";

import { MapPin, Send } from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { ContactPicker } from "@/components/rdv/ContactPicker";
import { Button, Field, Input, Textarea, Toggle, useToast } from "@/components/ui";
import { createRdv, listContacts, sendRdvInvite, updateRdv } from "@/lib/data";
import { combineDateTime, nextQuarterHour, splitDateTime } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import type { RendezvousWithContacts } from "@/lib/types";

/** Formulaire de création / modification d'un rendez-vous (participants, date, heure, lieu, notes). */
export function RdvForm({
  initial,
  preselectedContactIds = [],
  onSaved,
}: {
  initial?: RendezvousWithContacts;
  preselectedContactIds?: string[];
  onSaved: (rdv: RendezvousWithContacts) => void;
}) {
  const toast = useToast();
  const { data: contacts, loading } = useAsyncData(listContacts, []);
  const init = useMemo(() => (initial ? splitDateTime(initial.appointment_at) : splitDateTime(nextQuarterHour())), [initial]);

  const [contactIds, setContactIds] = useState<string[]>(initial ? initial.contacts.map((c) => c.id) : preselectedContactIds);
  const [date, setDate] = useState(init.date);
  const [time, setTime] = useState(init.time);
  const [title, setTitle] = useState(initial?.title ?? "");
  const [location, setLocation] = useState(initial?.location ?? "");
  const [notes, setNotes] = useState(initial?.notes ?? "");
  const [happened, setHappened] = useState(false);
  const [happenedTouched, setHappenedTouched] = useState(false);
  const [invite, setInvite] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  /** participants associés à un ami SeeU : on peut leur envoyer le rendez-vous */
  const friendsSelected = useMemo(
    () => (contacts ?? []).filter((c) => contactIds.includes(c.id) && c.linked_user_id),
    [contactIds, contacts]
  );

  const isPast = useMemo(() => {
    if (!date || !time) return false;
    return combineDateTime(date, time).getTime() < Date.now();
  }, [date, time]);

  useEffect(() => {
    if (!initial && !happenedTouched) setHappened(isPast);
  }, [isPast, happenedTouched, initial]);

  const selectedNames = useMemo(
    () => contactIds.map((id) => contacts?.find((c) => c.id === id)?.name).filter(Boolean) as string[],
    [contactIds, contacts]
  );
  const placeholderTitle = selectedNames.length ? `Avec ${selectedNames.join(", ")}` : "Ex. Déjeuner, café, visio…";

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!contactIds.length) return setError("Choisissez au moins un contact.");
    if (!date || !time) return setError("Indiquez la date et l'heure.");
    setBusy(true);
    try {
      const appointment_at = combineDateTime(date, time).toISOString();
      const base = { title: title || null, location: location || null, notes: notes || null, appointment_at };
      const rdv = initial
        ? await updateRdv(initial.id, base, contactIds)
        : await createRdv({ ...base, status: happened ? "valide" : "planifie" }, contactIds);
      if (!initial && invite && friendsSelected.length) {
        const results = await Promise.allSettled(friendsSelected.map((c) => sendRdvInvite(rdv.id, c.linked_user_id as string)));
        const sent = results.filter((r) => r.status === "fulfilled").length;
        if (sent) toast.success(sent > 1 ? `Invitations envoyées à ${sent} amis` : `Invitation envoyée à ${friendsSelected[0].name}`);
        if (sent < results.length) toast.error("Une invitation n'a pas pu être envoyée : réessayez depuis le rendez-vous.");
      }
      onSaved(rdv);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Enregistrement impossible");
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="space-y-5" noValidate>
      <Field label="Participants" required>
        <ContactPicker contacts={contacts ?? []} selected={contactIds} onChange={setContactIds} loading={loading} />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Date" htmlFor="date" required>
          <Input id="date" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
        </Field>
        <Field label="Heure" htmlFor="time" required>
          <Input id="time" type="time" value={time} onChange={(e) => setTime(e.target.value)} required />
        </Field>
      </div>

      <Field label="Titre (facultatif)" htmlFor="title">
        <Input id="title" value={title} onChange={(e) => setTitle(e.target.value)} placeholder={placeholderTitle} maxLength={120} />
      </Field>

      <Field label="Lieu (facultatif)" htmlFor="location">
        <div className="relative">
          <MapPin className="pointer-events-none absolute left-3.5 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" />
          <Input id="location" value={location} onChange={(e) => setLocation(e.target.value)} placeholder="Café, adresse, visio…" className="pl-11" maxLength={200} />
        </div>
      </Field>

      <Field label="Notes (facultatif)" htmlFor="notes">
        <Textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Idées de sujets, à ne pas oublier…" rows={3} />
      </Field>

      {!initial && (
        <div className="flex items-start justify-between gap-4 rounded-2xl border border-gray-200 p-4 dark:border-gray-800">
          <div>
            <p className="font-medium text-gray-900 dark:text-gray-100">Ce rendez-vous a déjà eu lieu</p>
            <p className="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
              {happened
                ? "Il sera enregistré comme une rencontre passée : la date de dernière rencontre des participants sera mise à jour."
                : "Il sera planifié : vous recevrez un rappel avant, puis pourrez le valider."}
            </p>
          </div>
          <Toggle
            checked={happened}
            onChange={(v) => {
              setHappened(v);
              setHappenedTouched(true);
            }}
            label="Ce rendez-vous a déjà eu lieu"
          />
        </div>
      )}

      {!initial && friendsSelected.length > 0 && (
        <div className="flex items-start justify-between gap-4 rounded-2xl border border-brand-200 bg-brand-50/60 p-4 dark:border-brand-900/60 dark:bg-brand-900/10">
          <div>
            <p className="flex items-center gap-1.5 font-medium text-gray-900 dark:text-gray-100">
              <Send className="h-4 w-4 text-brand-600 dark:text-brand-300" /> Envoyer à {friendsSelected.map((c) => c.name).join(", ")}
            </p>
            <p className="mt-0.5 text-xs text-gray-500 dark:text-gray-400">
              {invite
                ? happened
                  ? "Votre ami recevra cette rencontre : s'il l'accepte, sa période est remise à zéro et vous partagez les photos."
                  : "Votre ami reçoit une invitation : s'il accepte, vous avez tous les deux le rendez-vous et une galerie de photos commune. Vos notes restent privées."
                : "Le rendez-vous reste uniquement chez vous. Vous pourrez l'envoyer plus tard depuis sa fiche."}
            </p>
          </div>
          <Toggle checked={invite} onChange={setInvite} label="Envoyer le rendez-vous à mes amis SeeU" />
        </div>
      )}

      {error && (
        <p role="alert" className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-200">
          {error}
        </p>
      )}

      {!initial && <p className="text-xs text-gray-500 dark:text-gray-400">Vous pourrez ajouter des photos une fois le rendez-vous enregistré.</p>}

      <Button type="submit" full size="lg" loading={busy}>
        {initial ? "Enregistrer les modifications" : happened ? "Enregistrer la rencontre" : "Planifier le rendez-vous"}
      </Button>
    </form>
  );
}
