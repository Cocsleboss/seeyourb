"use client";

import { Check, MapPin, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Avatar, Button, Card, useToast } from "@/components/ui";
import { respondRdvInvite } from "@/lib/data";
import { capitalize, formatTime, relativeDayLabel } from "@/lib/dates";
import type { IncomingInvite } from "@/lib/types";

/**
 * Invitations à un rendez-vous reçues d'amis SeeU : accepter (le rendez-vous est ajouté chez moi,
 * rattaché au contact associé à l'ami) ou refuser.
 */
export function IncomingInvites({ invites, onChanged }: { invites: IncomingInvite[]; onChanged: () => void }) {
  const toast = useToast();
  const router = useRouter();
  const [busy, setBusy] = useState<string | null>(null);

  const respond = async (inv: IncomingInvite, accept: boolean) => {
    setBusy(inv.id + (accept ? ":yes" : ":no"));
    try {
      const rdvId = await respondRdvInvite(inv.id, accept);
      if (accept && rdvId) {
        toast.success(
          inv.rdv_status === "valide" ? "Rencontre ajoutée : votre période est remise à zéro" : "Rendez-vous accepté et ajouté à votre agenda"
        );
        router.push(`/rdv/${rdvId}`);
      } else {
        toast.info("Invitation refusée");
        onChanged();
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Réponse impossible");
      onChanged();
    } finally {
      setBusy(null);
    }
  };

  if (!invites.length) return null;

  return (
    <div className="space-y-2">
      {invites.map((inv) => {
        const at = new Date(inv.appointment_at);
        const past = inv.rdv_status === "valide";
        return (
          <Card key={inv.id} className="space-y-3 border-brand-200 bg-brand-50/60 dark:border-brand-900/60 dark:bg-brand-900/10">
            <div className="flex items-start gap-3">
              <Avatar name={inv.from_name} size={44} />
              <div className="min-w-0 flex-1">
                <p className="text-[15px] font-semibold text-gray-900 dark:text-gray-100">
                  {inv.from_name} {past ? "partage une rencontre avec vous" : "vous propose un rendez-vous"}
                </p>
                {inv.title && <p className="truncate text-sm text-gray-700 dark:text-gray-200">{inv.title}</p>}
                <p className="text-sm text-gray-600 dark:text-gray-300">
                  {capitalize(relativeDayLabel(at))} à {formatTime(at)}
                </p>
                {inv.location && (
                  <p className="flex items-center gap-1 truncate text-sm text-gray-600 dark:text-gray-300">
                    <MapPin className="h-3.5 w-3.5 shrink-0" /> <span className="truncate">{inv.location}</span>
                  </p>
                )}
              </div>
            </div>
            <div className="flex gap-2">
              <Button variant="secondary" size="sm" className="flex-1" disabled={busy !== null} loading={busy === inv.id + ":no"} onClick={() => respond(inv, false)}>
                <X className="h-4 w-4" /> Refuser
              </Button>
              <Button size="sm" className="flex-1" disabled={busy !== null} loading={busy === inv.id + ":yes"} onClick={() => respond(inv, true)}>
                <Check className="h-4 w-4" /> Accepter
              </Button>
            </div>
          </Card>
        );
      })}
    </div>
  );
}
