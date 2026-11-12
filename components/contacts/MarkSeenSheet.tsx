"use client";

import { useEffect, useState } from "react";
import { Button, Field, Input, Sheet, Textarea, useToast } from "@/components/ui";
import { logMeeting } from "@/lib/data";
import { todayISO } from "@/lib/dates";
import type { RendezvousWithContacts } from "@/lib/types";

/**
 * "Vu aujourd'hui" : enregistre une rencontre passée (rendez-vous validé) pour un contact.
 * Met à jour automatiquement la date de dernière rencontre et la prochaine échéance.
 */
export function MarkSeenSheet({
  contact,
  open,
  onClose,
  onDone,
}: {
  contact: { id: string; name: string } | null;
  open: boolean;
  onClose: () => void;
  onDone?: (rdv: RendezvousWithContacts) => void;
}) {
  const toast = useToast();
  const [date, setDate] = useState(todayISO());
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (open) {
      setDate(todayISO());
      setNotes("");
    }
  }, [open, contact?.id]);

  if (!contact) return null;

  const submit = async () => {
    if (!date) return;
    setBusy(true);
    try {
      const rdv = await logMeeting([contact.id], date, { notes: notes || null });
      toast.success(`Rencontre avec ${contact.name} enregistrée`);
      onDone?.(rdv);
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Impossible d'enregistrer");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Sheet open={open} onClose={busy ? () => {} : onClose} title={`Vu ${contact.name}`}>
      <form
        className="space-y-4"
        onSubmit={(e) => {
          e.preventDefault();
          submit();
        }}
      >
        <Field label="Quand l'avez-vous vu(e) ?" htmlFor="seen-date" required>
          <Input id="seen-date" type="date" value={date} max={todayISO()} onChange={(e) => setDate(e.target.value)} required />
        </Field>
        <Field label="Une note (facultatif)" htmlFor="seen-notes">
          <Textarea id="seen-notes" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Un souvenir, un détail à retenir…" rows={2} />
        </Field>
        <p className="text-xs text-gray-500 dark:text-gray-400">
          La date de dernière rencontre et la prochaine échéance seront mises à jour automatiquement. La rencontre
          apparaîtra dans l&apos;historique.
        </p>
        <Button type="submit" full size="lg" loading={busy}>
          Enregistrer la rencontre
        </Button>
      </form>
    </Sheet>
  );
}
