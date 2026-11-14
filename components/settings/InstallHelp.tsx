"use client";

import { CheckCircle2, Share, Smartphone, SquarePlus } from "lucide-react";
import { useEffect, useState } from "react";
import { Card } from "@/components/ui";
import { isIOS, isStandalone } from "@/lib/push-client";

export function InstallHelp() {
  const [standalone, setStandalone] = useState<boolean | null>(null);
  const [ios, setIos] = useState(false);
  useEffect(() => {
    setStandalone(isStandalone());
    setIos(isIOS());
  }, []);

  if (standalone === null) return null;

  if (standalone) {
    return (
      <Card className="flex items-center gap-3 text-sm">
        <CheckCircle2 className="h-5 w-5 shrink-0 text-emerald-600" />
        <span className="text-gray-700 dark:text-gray-200">Installée sur cet appareil</span>
      </Card>
    );
  }

  return (
    <Card className="space-y-3 text-sm">
      <div className="flex items-center gap-2 font-semibold text-gray-900 dark:text-gray-100">
        <Smartphone className="h-5 w-5 text-brand-600" /> Installer SeeU
      </div>
      <p className="text-gray-600 dark:text-gray-300">
        Ajoutez l&apos;app à votre écran d&apos;accueil pour l&apos;ouvrir comme une application et recevoir les notifications.
      </p>
      <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/60">
          <p className="font-medium text-gray-900 dark:text-gray-100">iPhone / iPad (Safari)</p>
          <ol className="mt-1 space-y-1 text-gray-700 dark:text-gray-200">
            <li className="flex items-center gap-2">
              1. Touchez <Share className="h-4 w-4 text-brand-600" /> Partager
            </li>
            <li className="flex items-center gap-2">
              2. Choisissez <SquarePlus className="h-4 w-4 text-brand-600" /> Sur l&apos;écran d&apos;accueil
            </li>
            <li>3. Ouvrez l&apos;app depuis la nouvelle icône</li>
          </ol>
        </div>
      {!ios && (
        <div className="rounded-xl bg-gray-50 p-3 dark:bg-gray-800/60">
          <p className="font-medium text-gray-900 dark:text-gray-100">Android (Chrome)</p>
          <p className="mt-1 text-gray-700 dark:text-gray-200">Menu ⋮ → « Installer l&apos;application » (ou acceptez la bannière proposée).</p>
        </div>
      )}
    </Card>
  );
}
