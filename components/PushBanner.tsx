"use client";

import { Bell, Share, SquarePlus, X } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { Button, useToast } from "@/components/ui";
import { useLocalStorage } from "@/lib/hooks";
import { getPushState, subscribeToPush, type PushState } from "@/lib/push-client";

/**
 * Bannière d'accueil : propose d'installer l'app (iPhone) ou d'activer les notifications push.
 * Masquable (mémorisé dans localStorage).
 */
export function PushBanner() {
  const toast = useToast();
  const [state, setState] = useState<PushState | null>(null);
  const [dismissed, setDismissed] = useLocalStorage<number>("seeyourb.push-banner-dismissed", 0);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    getPushState().then(setState);
  }, []);

  // Réaffiche la bannière 7 jours après avoir été masquée
  const hidden = dismissed > 0 && Date.now() - dismissed < 7 * 86_400_000;
  if (!state || hidden || state === "subscribed" || state === "unsupported" || state === "no-key") return null;

  const close = () => setDismissed(Date.now());

  const enable = async () => {
    setBusy(true);
    const res = await subscribeToPush();
    setBusy(false);
    if (res.ok) {
      setState("subscribed");
      toast.success("Notifications activées 🎉");
    } else if (res.reason === "denied") {
      setState("denied");
    } else {
      toast.error(res.message || "Activation impossible");
    }
  };

  return (
    <div className="relative rounded-2xl border border-brand-200 bg-brand-50 p-4 dark:border-brand-900/60 dark:bg-brand-900/20">
      <button
        type="button"
        onClick={close}
        aria-label="Masquer"
        className="absolute right-2 top-2 flex h-8 w-8 items-center justify-center rounded-full text-brand-700/70 hover:bg-brand-100 dark:text-brand-200 dark:hover:bg-brand-900/40"
      >
        <X className="h-4 w-4" />
      </button>
      <div className="flex gap-3">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white text-brand-600 shadow-sm dark:bg-gray-900 dark:text-brand-300">
          <Bell className="h-5 w-5" />
        </div>
        <div className="min-w-0 flex-1 pr-6">
          {state === "needs-install" && (
            <>
              <p className="font-semibold text-gray-900 dark:text-gray-100">Installez SeeYourB sur votre iPhone</p>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                Pour recevoir les rappels, ajoutez l&apos;app à l&apos;écran d&apos;accueil :
              </p>
              <ol className="mt-2 space-y-1 text-sm text-gray-700 dark:text-gray-200">
                <li className="flex items-center gap-2">
                  <span className="font-semibold">1.</span> Touchez <Share className="h-4 w-4 text-brand-600" /> <span>Partager</span> en bas de Safari
                </li>
                <li className="flex items-center gap-2">
                  <span className="font-semibold">2.</span> Choisissez <SquarePlus className="h-4 w-4 text-brand-600" /> <span>Sur l&apos;écran d&apos;accueil</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="font-semibold">3.</span> Ouvrez l&apos;app depuis l&apos;icône, puis activez les notifications
                </li>
              </ol>
            </>
          )}
          {state === "not-subscribed" && (
            <>
              <p className="font-semibold text-gray-900 dark:text-gray-100">Activer les rappels</p>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                Recevez une notification quand un contact est à recontacter et avant chaque rendez-vous.
              </p>
              <Button className="mt-3" size="sm" loading={busy} onClick={enable}>
                <Bell className="h-4 w-4" /> Activer les notifications
              </Button>
            </>
          )}
          {state === "denied" && (
            <>
              <p className="font-semibold text-gray-900 dark:text-gray-100">Notifications bloquées</p>
              <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">
                Autorisez-les dans les réglages de votre appareil (Réglages → Notifications → SeeYourB), ou activez les
                rappels par email dans les{" "}
                <Link href="/settings" className="font-medium text-brand-600 underline">
                  réglages
                </Link>
                .
              </p>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
