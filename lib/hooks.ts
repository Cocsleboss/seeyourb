"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { cachedSignedUrl, getSignedUrl, getSignedUrls } from "@/lib/photos";

/** URL signée d'une photo privée (null tant qu'elle n'est pas prête ou si pas de chemin). */
export function useSignedUrl(path: string | null | undefined): string | null {
  const [url, setUrl] = useState<string | null>(() => cachedSignedUrl(path));
  useEffect(() => {
    let alive = true;
    if (!path) {
      setUrl(null);
      return;
    }
    const cached = cachedSignedUrl(path);
    if (cached) {
      setUrl(cached);
      return;
    }
    getSignedUrl(path).then((u) => {
      if (alive) setUrl(u);
    });
    return () => {
      alive = false;
    };
  }, [path]);
  return url;
}

/** URLs signées pour une liste de chemins : { path: url }. */
export function useSignedUrls(paths: (string | null | undefined)[]): Record<string, string> {
  const key = paths.filter(Boolean).join("|");
  const [urls, setUrls] = useState<Record<string, string>>({});
  useEffect(() => {
    let alive = true;
    const list = key ? key.split("|") : [];
    if (!list.length) {
      setUrls({});
      return;
    }
    getSignedUrls(list).then((u) => {
      if (alive) setUrls(u);
    });
    return () => {
      alive = false;
    };
  }, [key]);
  return urls;
}

/**
 * Chargement de données avec état loading/error et fonction reload().
 * Le loader doit être stable (useCallback) ou dépendre de `deps`.
 */
export function useAsyncData<T>(loader: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const loaderRef = useRef(loader);
  loaderRef.current = loader;
  const version = useRef(0);

  const reload = useCallback(async (silent = true) => {
    const v = ++version.current;
    if (!silent) setLoading(true);
    try {
      const result = await loaderRef.current();
      if (v === version.current) {
        setData(result);
        setError(null);
      }
    } catch (e) {
      if (v === version.current) setError(e instanceof Error ? e.message : "Erreur de chargement");
    } finally {
      if (v === version.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    reload(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  // Rechargement quand l'app revient au premier plan (PWA iOS)
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === "visible") reload(true);
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [reload]);

  return { data, loading, error, reload, setData };
}

/** Valeur persistée dans localStorage (tolérant aux erreurs / mode privé). */
export function useLocalStorage<T>(key: string, initial: T): [T, (v: T) => void] {
  const [value, setValue] = useState<T>(initial);
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(key);
      if (raw !== null) setValue(JSON.parse(raw) as T);
    } catch {
      /* ignore */
    }
  }, [key]);
  const set = useCallback(
    (v: T) => {
      setValue(v);
      try {
        window.localStorage.setItem(key, JSON.stringify(v));
      } catch {
        /* ignore */
      }
    },
    [key]
  );
  return [value, set];
}
