"use client";

import { Trash2 } from "lucide-react";
import { useEffect, useMemo, useState, type FormEvent } from "react";
import { PhotoPicker } from "@/components/PhotoPicker";
import { CategoryPicker } from "@/components/contacts/CategoryPicker";
import { FrequencyPicker } from "@/components/contacts/FrequencyPicker";
import { Avatar, Button, Field, Input, Textarea, useToast } from "@/components/ui";
import { createContact, setContactPhoto, updateContact } from "@/lib/data";
import { addFrequency, formatDateLong, frequencyLabel, todayISO } from "@/lib/dates";
import type { Contact, ContactInput, FrequencyUnit } from "@/lib/types";

/** Formulaire de création / modification d'un contact (gère aussi l'enregistrement et la photo). */
export function ContactForm({ initial, onSaved }: { initial?: Contact; onSaved: (contact: Contact) => void }) {
  const toast = useToast();
  const isEdit = Boolean(initial);

  const [name, setName] = useState(initial?.name ?? "");
  const [category, setCategory] = useState<string | null>(initial?.category ?? null);
  const [lastMeeting, setLastMeeting] = useState(initial?.last_meeting_date ?? todayISO());
  const [freqValue, setFreqValue] = useState<number>(initial?.frequency_value ?? 1);
  const [freqUnit, setFreqUnit] = useState<FrequencyUnit>(initial?.frequency_unit ?? "months");
  const [phone, setPhone] = useState(initial?.phone ?? "");
  const [email, setEmail] = useState(initial?.email ?? "");
  const [birthday, setBirthday] = useState(initial?.birthday ?? "");
  const [notes, setNotes] = useState(initial?.notes ?? "");
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoRemoved, setPhotoRemoved] = useState(false);
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    if (!photoFile) {
      setPreview(null);
      return;
    }
    const url = URL.createObjectURL(photoFile);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [photoFile]);

  const nextDue = useMemo(() => {
    try {
      return lastMeeting && freqValue >= 1 ? formatDateLong(addFrequency(lastMeeting, freqValue, freqUnit)) : null;
    } catch {
      return null;
    }
  }, [lastMeeting, freqValue, freqUnit]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const errs: Record<string, string> = {};
    if (!name.trim()) errs.name = "Le nom est obligatoire.";
    if (!lastMeeting) errs.lastMeeting = "Indiquez la date de la dernière rencontre.";
    if (!Number.isInteger(freqValue) || freqValue < 1) errs.freq = "La fréquence doit être d'au moins 1.";
    if (email && !/^\S+@\S+\.\S+$/.test(email.trim())) errs.email = "Adresse email invalide.";
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setBusy(true);
    try {
      const values: ContactInput = {
        name: name.trim(),
        category,
        phone: phone.trim() || null,
        email: email.trim() || null,
        birthday: birthday || null,
        notes: notes.trim() || null,
        last_meeting_date: lastMeeting,
        frequency_value: freqValue,
        frequency_unit: freqUnit,
      };
      let contact = initial ? await updateContact(initial.id, values) : await createContact(values);
      if (photoFile) contact = await setContactPhoto(contact, photoFile);
      else if (photoRemoved && contact.photo_path) contact = await setContactPhoto(contact, null);
      onSaved(contact);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Enregistrement impossible");
    } finally {
      setBusy(false);
    }
  };

  const currentPhotoPath = photoRemoved ? null : (initial?.photo_path ?? null);
  const hasPhoto = Boolean(preview || currentPhotoPath);

  return (
    <form onSubmit={submit} className="space-y-5" noValidate>
      {/* Photo */}
      <div className="flex flex-col items-center gap-3">
        <Avatar name={name || "?"} src={preview} path={currentPhotoPath} size={96} className="shadow-md" />
        <div className="flex gap-2">
          <PhotoPicker
            variant="secondary"
            onPick={(files) => {
              setPhotoFile(files[0] ?? null);
              setPhotoRemoved(false);
            }}
          >
            {hasPhoto ? "Changer la photo" : "Ajouter une photo"}
          </PhotoPicker>
          {hasPhoto && (
            <Button
              variant="outline"
              onClick={() => {
                setPhotoFile(null);
                setPhotoRemoved(true);
              }}
            >
              <Trash2 className="h-4 w-4" /> Retirer
            </Button>
          )}
        </div>
      </div>

      <Field label="Nom" htmlFor="name" required error={errors.name}>
        <Input
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Ex. Marie Dupont"
          maxLength={120}
          autoComplete="off"
          autoFocus={!isEdit}
          required
        />
      </Field>

      <Field label="Catégorie">
        <CategoryPicker value={category} onChange={setCategory} />
      </Field>

      <Field label="Dernière fois que vous l'avez vu(e)" htmlFor="last" required error={errors.lastMeeting}>
        <Input id="last" type="date" value={lastMeeting} max={todayISO()} onChange={(e) => setLastMeeting(e.target.value)} required />
      </Field>

      <Field label="À revoir tous les…" required error={errors.freq}>
        <FrequencyPicker
          value={freqValue}
          unit={freqUnit}
          onChange={(v, u) => {
            setFreqValue(v);
            setFreqUnit(u);
          }}
        />
        {nextDue && (
          <p className="mt-2 rounded-xl bg-brand-50 px-3 py-2 text-sm text-brand-800 dark:bg-brand-900/20 dark:text-brand-200">
            {freqValue >= 1 && `${frequencyLabel(freqValue, freqUnit)} · `}
            Prochaine échéance : <span className="font-semibold">{nextDue}</span>
          </p>
        )}
      </Field>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Téléphone" htmlFor="phone">
          <Input id="phone" type="tel" inputMode="tel" autoComplete="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="06 12 34 56 78" />
        </Field>
        <Field label="Email" htmlFor="email" error={errors.email}>
          <Input id="email" type="email" inputMode="email" autoCapitalize="none" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="marie@exemple.com" />
        </Field>
      </div>

      <Field label="Anniversaire" htmlFor="birthday" hint="Vous recevrez un rappel le jour J">
        <Input id="birthday" type="date" value={birthday} max={todayISO()} onChange={(e) => setBirthday(e.target.value)} />
      </Field>

      <Field label="Notes" htmlFor="notes">
        <Textarea
          id="notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Ce qu'il faut retenir : enfants, passions, sujets à aborder…"
          rows={3}
        />
      </Field>

      <Button type="submit" full size="lg" loading={busy}>
        {isEdit ? "Enregistrer les modifications" : "Ajouter le contact"}
      </Button>
    </form>
  );
}
