"use client";

import { Check, RotateCcw, X } from "lucide-react";
import { useState } from "react";
import { Button, ConfirmSheet, useToast } from "@/components/ui";
import { setRdvStatus } from "@/lib/data";
import { formatDateTime } from "@/lib/dates";
import type { RendezvousWithContacts } from "@/lib/types";

/**
 * Boutons de cycle de vie d'un rendez-vous :
 *  - planifié  → "A eu lieu" (met à jour la date de dernière rencontre des contacts) / "Annulé"
 *  - validé ou annulé → "Remettre en planifié"
 */
export function RdvStatusActions({
  rdv,
  onChanged,
  size = "md",
}: {
  rdv: RendezvousWithContacts;
  onChanged: (rdv: RendezvousWithContacts) => void;
  size?: "sm" | "md" | "lg";
}) {
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  const [confirmFuture, setConfirmFuture] = useState(false);

  const change = async (status: "planifie" | "valide" | "annule") => {
    setBusy(status);
    try {
      const updated = await setRdvStatus(rdv.id, status);
      if (status === "valide") {
        toast.success(
          rdv.contacts.length
            ? "Rendez-vous validé : date de dernière rencontre mise à jour"
            : "Rendez-vous validé"
        );
      } else if (status === "annule") {
        toast.info("Rendez-vous annulé");
      } else {
        toast.info("Rendez-vous remis en planifié");
      }
      onChanged(updated);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Impossible de changer le statut");
    } finally {
      setBusy(null);
    }
  };

  const isFuture = new Date(rdv.appointment_at).getTime() > Date.now() + 5 * 60_000;

  if (rdv.status === "planifie") {
    return (
      <>
        <div className="flex gap-2">
          <Button
            variant="success"
            size={size}
            full
            loading={busy === "valide"}
            disabled={busy !== null}
            onClick={() => (isFuture ? setConfirmFuture(true) : change("valide"))}
          >
            <Check className="h-5 w-5" /> A eu lieu
          </Button>
          <Button
            variant="outline"
            size={size}
            full
            loading={busy === "annule"}
            disabled={busy !== null}
            onClick={() => change("annule")}
          >
            <X className="h-5 w-5" /> Annulé
          </Button>
        </div>
        <ConfirmSheet
          open={confirmFuture}
          onClose={() => setConfirmFuture(false)}
          onConfirm={() => change("valide")}
          title="Ce rendez-vous est prévu plus tard"
          message={`Il est planifié le ${formatDateTime(rdv.appointment_at)}. Le marquer quand même comme ayant eu lieu ?`}
          confirmLabel="Oui, il a eu lieu"
        />
      </>
    );
  }

  return (
    <Button variant="ghost" size={size} loading={busy === "planifie"} disabled={busy !== null} onClick={() => change("planifie")}>
      <RotateCcw className="h-4 w-4" /> Remettre en planifié
    </Button>
  );
}
