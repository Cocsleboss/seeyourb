"use client";

/** Utilitaires Web Push côté navigateur (abonnement, détection iOS / mode installé). */

export function pushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  );
}

export function isIOS(): boolean {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent;
  return /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
}

export function isAndroid(): boolean {
  return typeof navigator !== "undefined" && /Android/i.test(navigator.userAgent);
}

/** true si l'app est lancée depuis l'écran d'accueil (PWA installée). */
export function isStandalone(): boolean {
  if (typeof window === "undefined") return false;
  const nav = navigator as Navigator & { standalone?: boolean };
  return window.matchMedia("(display-mode: standalone)").matches || nav.standalone === true;
}

export type PushState =
  | "unsupported" // navigateur sans Web Push
  | "needs-install" // iOS : il faut d'abord ajouter l'app à l'écran d'accueil
  | "denied" // permission refusée dans les réglages
  | "subscribed"
  | "not-subscribed"
  | "no-key"; // NEXT_PUBLIC_VAPID_PUBLIC_KEY absente

export async function getPushState(): Promise<PushState> {
  if (!process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY) return "no-key";
  if (!pushSupported()) return isIOS() && !isStandalone() ? "needs-install" : "unsupported";
  if (Notification.permission === "denied") return "denied";
  try {
    const reg = await navigator.serviceWorker.getRegistration();
    const sub = await reg?.pushManager.getSubscription();
    return sub ? "subscribed" : "not-subscribed";
  } catch {
    return "not-subscribed";
  }
}

export function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = window.atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

export interface SubscribeResult {
  ok: boolean;
  reason?: "unsupported" | "needs-install" | "denied" | "no-key" | "server" | "error";
  message?: string;
}

/**
 * Demande la permission puis abonne l'appareil. À appeler DIRECTEMENT dans un gestionnaire de clic
 * (iOS exige un geste utilisateur pour Notification.requestPermission).
 */
export async function subscribeToPush(): Promise<SubscribeResult> {
  const key = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  if (!key) return { ok: false, reason: "no-key", message: "Clé VAPID publique manquante (NEXT_PUBLIC_VAPID_PUBLIC_KEY)." };
  if (!pushSupported()) {
    return isIOS() && !isStandalone()
      ? { ok: false, reason: "needs-install", message: "Ajoutez d'abord l'app à l'écran d'accueil." }
      : { ok: false, reason: "unsupported", message: "Ce navigateur ne supporte pas les notifications push." };
  }
  try {
    const permission = await Notification.requestPermission();
    if (permission !== "granted") {
      return { ok: false, reason: "denied", message: "Permission refusée. Activez les notifications dans les réglages." };
    }
    const reg = (await navigator.serviceWorker.getRegistration()) ?? (await navigator.serviceWorker.register("/sw.js"));
    await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();
    if (!sub) {
      sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(key) as BufferSource,
      });
    }
    const res = await fetch("/api/push/subscribe", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ subscription: sub.toJSON(), userAgent: navigator.userAgent }),
    });
    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      return { ok: false, reason: "server", message: data.error || "Impossible d'enregistrer l'abonnement." };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, reason: "error", message: e instanceof Error ? e.message : "Erreur inconnue" };
  }
}

export async function unsubscribeFromPush(): Promise<void> {
  if (!pushSupported()) return;
  const reg = await navigator.serviceWorker.getRegistration();
  const sub = await reg?.pushManager.getSubscription();
  if (!sub) return;
  await fetch("/api/push/subscribe", {
    method: "DELETE",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ endpoint: sub.endpoint }),
  }).catch(() => {});
  await sub.unsubscribe().catch(() => {});
}

/** Renvoie l'état après synchronisation : si abonné localement, s'assure que le serveur connaît l'abonnement. */
export async function syncPushSubscription(): Promise<void> {
  if (!pushSupported()) return;
  try {
    const reg = await navigator.serviceWorker.getRegistration();
    const sub = await reg?.pushManager.getSubscription();
    if (!sub) return;
    await fetch("/api/push/subscribe", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ subscription: sub.toJSON(), userAgent: navigator.userAgent }),
    });
  } catch {
    /* ignore */
  }
}
