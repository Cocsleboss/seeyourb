import { createClient } from "@/lib/supabase/client";

export const PHOTO_BUCKET = "photos";
const SIGN_TTL_SECONDS = 60 * 60; // 1 h
const REFRESH_BEFORE_MS = 10 * 60 * 1000; // on re-signe 10 min avant expiration

const urlCache = new Map<string, { url: string; expiresAt: number }>();
const pending = new Map<string, Promise<string | null>>();

export function cachedSignedUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  const hit = urlCache.get(path);
  if (hit && hit.expiresAt - REFRESH_BEFORE_MS > Date.now()) return hit.url;
  return null;
}

/** URL signée (privée, 1 h) pour un fichier du bucket "photos", avec cache mémoire. */
export async function getSignedUrl(path: string | null | undefined): Promise<string | null> {
  if (!path) return null;
  const cached = cachedSignedUrl(path);
  if (cached) return cached;
  const inflight = pending.get(path);
  if (inflight) return inflight;
  const p = (async () => {
    const { data, error } = await createClient().storage.from(PHOTO_BUCKET).createSignedUrl(path, SIGN_TTL_SECONDS);
    if (error || !data) return null;
    urlCache.set(path, { url: data.signedUrl, expiresAt: Date.now() + SIGN_TTL_SECONDS * 1000 });
    return data.signedUrl;
  })();
  pending.set(path, p);
  try {
    return await p;
  } finally {
    pending.delete(path);
  }
}

/** Signe plusieurs chemins en une seule requête. Renvoie { path: url }. */
export async function getSignedUrls(paths: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  const missing: string[] = [];
  for (const p of Array.from(new Set(paths.filter(Boolean)))) {
    const c = cachedSignedUrl(p);
    if (c) out[p] = c;
    else missing.push(p);
  }
  if (missing.length) {
    const { data } = await createClient().storage.from(PHOTO_BUCKET).createSignedUrls(missing, SIGN_TTL_SECONDS);
    for (const item of data ?? []) {
      if (item.signedUrl && item.path) {
        urlCache.set(item.path, { url: item.signedUrl, expiresAt: Date.now() + SIGN_TTL_SECONDS * 1000 });
        out[item.path] = item.signedUrl;
      }
    }
  }
  return out;
}

function loadImage(blob: Blob): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Image illisible"));
    };
    img.src = url;
  });
}

/**
 * Redimensionne/compresse une image côté client (les photos iPhone font 3-6 Mo).
 * Renvoie un JPEG ≤ maxDim px. Si l'image ne peut pas être décodée (HEIC hors Safari), renvoie l'original.
 */
export async function compressImage(file: Blob, maxDim = 1600, quality = 0.82): Promise<Blob> {
  try {
    const img = await loadImage(file);
    const w0 = img.naturalWidth || img.width;
    const h0 = img.naturalHeight || img.height;
    if (!w0 || !h0) return file;
    const scale = Math.min(1, maxDim / Math.max(w0, h0));
    const w = Math.max(1, Math.round(w0 * scale));
    const h = Math.max(1, Math.round(h0 * scale));
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    if (!ctx) return file;
    ctx.drawImage(img, 0, 0, w, h);
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
    return blob && blob.size > 0 ? blob : file;
  } catch {
    return file;
  }
}

function uuid(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

/** Compresse puis envoie une image dans le dossier privé de l'utilisateur. Renvoie le chemin stocké. */
export async function uploadImage(file: Blob, userId: string): Promise<string> {
  const blob = await compressImage(file);
  const type = blob.type || file.type || "image/jpeg";
  const ext =
    type === "image/png" ? "png" : type === "image/webp" ? "webp" : type === "image/gif" ? "gif" : type === "image/heic" || type === "image/heif" ? "heic" : "jpg";
  const path = `${userId}/${uuid()}.${ext}`;
  const { error } = await createClient()
    .storage.from(PHOTO_BUCKET)
    .upload(path, blob, { contentType: type, upsert: false, cacheControl: "3600" });
  if (error) throw new Error(error.message);
  return path;
}

export async function removeFiles(paths: string[]): Promise<void> {
  const clean = paths.filter(Boolean);
  if (!clean.length) return;
  await createClient().storage.from(PHOTO_BUCKET).remove(clean);
  clean.forEach((p) => urlCache.delete(p));
}
