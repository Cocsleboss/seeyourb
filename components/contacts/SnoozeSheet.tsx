"use client";

import { useEffect, useState } from "react";
import { Button, Field, Input, Sheet, useToast } from "@/components/ui";
import { snoozeContact } from "@/lib/data";
import { addFrequency, formatDate, todayISO } from "@/lib/dates";
import type { Contact } from "@/lib/types";

const OPTIONS = [
  { label: "3 jours", days: 3 },
  { label: "1 semaine", days: 7 },
  { label: "2 semaines", days: 14 },
  { label: "1 mois", days: 30 },
];

/** "Reporter" : repousse l'échéance d'un contact sans créer de rendez-vous. */
export function SnoozeSheet({
  contact,
  open,
  onClose,
  onDone,
}: {
  contact: { id: string; name: string } | null;
  open: boolean;
  onClose: () => void;
  onDone?: (contact: Contact) => void;
}) {
  const toast = useToast();
  const [custom, setCustom] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (open) setCustom("");
  }, [open, contact?.id]);

  if (!contact) return null;

  const apply = async (untilISO: string) => {
    setBusy(true);
    try {
      const updated = await snoozeContact(contact.id, untilISO);
      toast.success(`Rappel reporté au ${formatDate(untilISO)}`);
      onDone?.(updated);
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Impossible de reporter");
    } finally {
      setBusy(false);
    }
  };

  const today = todayISO();

  return (
    <Sheet open={open} onClose={busy ? () => {} : onClose} title={`Reporter ${contact.name}`}>
      <p className="text-sm text-gray-500 dark:text-gray-400">Me le rappeler plus tard, dans :</p>
      <div className="mt-3 grid grid-cols-2 gap-2">
        {OPTIONS.map((o) => (
          <Button key={o.days} variant="secondary" disabled={busy} onClick={() => apply(addFrequency(today, o.days, "days"))}>
            {o.label}
          </Button>
        ))}
      </div>
      <form
        className="mt-4 space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          if (custom) apply(custom);
        }}
      >
        <Field label="Ou à une date précise" htmlFor="snooze-date">
          <Input id="snooze-date" type="date" min={today} value={custom} onChange={(e) => setCustom(e.target.value)} />
        </Field>
        <Button type="submit" full disabled={!custom} loading={busy}>
          Reporter à cette date
        </Button>
      </form>
    </Sheet>
  );
}
