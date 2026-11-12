"use client";

import { MapPin } from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { ContactPicker } from "@/components/rdv/ContactPicker";
import { Button, Field, Input, Textarea, Toggle, useToast } from "@/components/ui";
import { createRdv, listContacts, updateRdv } from "@/lib/data";
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
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
