"use client";

import { useEffect } from "react";
import { syncPushSubscription } from "@/lib/push-client";

/** Enregistre le service worker (PWA + push) et resynchronise l'abonnement push. */
export function PwaRegister() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    const register = async () => {
      try {
        const reg = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
        reg.update().catch(() => {});
        await syncPushSubscription();
      } catch (e) {
        console.warn("Service worker non enregistré :", e);
      }
    };
    if (document.readyState === "complete") register();
    else window.addEventListener("load", register, { once: true });
  }, []);
  return null;
}
