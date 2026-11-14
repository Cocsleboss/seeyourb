"use client";

import { ChevronLeft, ChevronRight, Trash2, X } from "lucide-react";
import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { useSignedUrls } from "@/lib/hooks";
import { formatDateTime } from "@/lib/dates";
import type { Photo } from "@/lib/types";

/** Grille de vignettes carrées + visionneuse plein écran (avec suppression optionnelle). */
export function PhotoGrid({
  photos,
  onDelete,
  canDelete,
  columns = 3,
  pendingCount = 0,
}: {
  photos: Photo[];
  onDelete?: (photo: Photo) => Promise<void> | void;
  /** limite la suppression à certaines photos (galerie partagée : seulement les siennes) */
  canDelete?: (photo: Photo) => boolean;
  columns?: 3 | 4;
  /** vignettes "en cours d'envoi" affichées en fin de grille */
  pendingCount?: number;
}) {
  const urls = useSignedUrls(photos.map((p) => p.storage_path));
  const [index, setIndex] = useState<number | null>(null);

  if (!photos.length && !pendingCount) return null;

  return (
    <>
      <div className={`grid gap-1.5 ${columns === 4 ? "grid-cols-4" : "grid-cols-3"}`}>
        {photos.map((p, i) => {
          const url = urls[p.storage_path];
          return (
            <button
              key={p.id}
              type="button"
              onClick={() => setIndex(i)}
              className="relative aspect-square overflow-hidden rounded-xl bg-gray-200 dark:bg-gray-800"
              aria-label={`Photo ${i + 1}`}
            >
              {url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={url} alt={p.caption ?? ""} className="h-full w-full object-cover" loading="lazy" />
              ) : (
                <div className="h-full w-full animate-pulse" />
              )}
            </button>
          );
        })}
        {Array.from({ length: pendingCount }).map((_, i) => (
          <div key={`pending-${i}`} className="aspect-square animate-pulse rounded-xl bg-brand-100 dark:bg-gray-800" />
        ))}
      </div>
      {index !== null && (
        <Lightbox
          photos={photos}
          urls={urls}
          index={index}
          onClose={() => setIndex(null)}
          onNavigate={setIndex}
          onDelete={
            onDelete && photos[index] && (!canDelete || canDelete(photos[index]))
              ? async (p) => {
                  await onDelete(p);
                  setIndex(null);
                }
              : undefined
          }
        />
      )}
    </>
  );
}

function Lightbox({
  photos,
  urls,
  index,
  onClose,
  onNavigate,
  onDelete,
}: {
  photos: Photo[];
  urls: Record<string, string>;
  index: number;
  onClose: () => void;
  onNavigate: (i: number) => void;
  onDelete?: (p: Photo) => Promise<void>;
}) {
  const photo = photos[index];
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [touchX, setTouchX] = useState<number | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
      if (e.key === "ArrowLeft" && index > 0) onNavigate(index - 1);
      if (e.key === "ArrowRight" && index < photos.length - 1) onNavigate(index + 1);
    };
    document.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [index, photos.length, onClose, onNavigate]);

  if (!photo) return null;
  const url = urls[photo.storage_path];

  return createPortal(
    <div
      className="fixed inset-0 z-[70] flex flex-col bg-black text-white"
      role="dialog"
      aria-modal="true"
      onTouchStart={(e) => setTouchX(e.touches[0].clientX)}
      onTouchEnd={(e) => {
        if (touchX === null) return;
        const dx = e.changedTouches[0].clientX - touchX;
        if (dx > 60 && index > 0) onNavigate(index - 1);
        if (dx < -60 && index < photos.length - 1) onNavigate(index + 1);
        setTouchX(null);
      }}
    >
      <div className="flex items-center justify-between px-3 pb-2" style={{ paddingTop: "max(0.75rem, env(safe-area-inset-top))" }}>
        <button type="button" onClick={onClose} aria-label="Fermer" className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10">
          <X className="h-5 w-5" />
        </button>
        <span className="text-sm text-white/80">
          {index + 1} / {photos.length}
        </span>
        {onDelete ? (
          <button
            type="button"
            onClick={() => setConfirm(true)}
            aria-label="Supprimer la photo"
            className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-red-300"
          >
            <Trash2 className="h-5 w-5" />
          </button>
        ) : (
          <span className="w-10" />
        )}
      </div>
      <div className="relative flex flex-1 items-center justify-center overflow-hidden">
        {url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={url} alt={photo.caption ?? ""} className="max-h-full max-w-full object-contain" />
        ) : (
          <div className="text-white/60">Chargement…</div>
        )}
        {index > 0 && (
          <button
            type="button"
            onClick={() => onNavigate(index - 1)}
            aria-label="Précédente"
            className="absolute left-2 top-1/2 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 sm:flex"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
        )}
        {index < photos.length - 1 && (
          <button
            type="button"
            onClick={() => onNavigate(index + 1)}
            aria-label="Suivante"
            className="absolute right-2 top-1/2 hidden h-11 w-11 -translate-y-1/2 items-center justify-center rounded-full bg-white/10 sm:flex"
          >
            <ChevronRight className="h-6 w-6" />
          </button>
        )}
      </div>
      <div className="px-4 pt-2 text-center text-xs text-white/70" style={{ paddingBottom: "max(1rem, env(safe-area-inset-bottom))" }}>
        {photo.caption ? <p className="mb-1 text-sm text-white">{photo.caption}</p> : null}
        {formatDateTime(photo.created_at)}
      </div>
      {confirm && (
        <div className="absolute inset-0 flex items-end justify-center bg-black/60 p-4 sm:items-center" onClick={() => !busy && setConfirm(false)}>
          <div className="w-full max-w-sm rounded-2xl bg-white p-5 text-gray-900 dark:bg-gray-900 dark:text-gray-100" onClick={(e) => e.stopPropagation()}>
            <p className="font-semibold">Supprimer cette photo ?</p>
            <p className="mt-1 text-sm text-gray-500">Cette action est définitive.</p>
            <div className="mt-4 flex gap-2">
              <button type="button" disabled={busy} onClick={() => setConfirm(false)} className="h-11 flex-1 rounded-xl bg-gray-100 font-semibold dark:bg-gray-800">
                Annuler
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={async () => {
                  if (!onDelete) return;
                  setBusy(true);
                  try {
                    await onDelete(photo);
                  } finally {
                    setBusy(false);
                    setConfirm(false);
                  }
                }}
                className="h-11 flex-1 rounded-xl bg-red-600 font-semibold text-white disabled:opacity-50"
              >
                {busy ? "Suppression…" : "Supprimer"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>,
    document.body
  );
}
