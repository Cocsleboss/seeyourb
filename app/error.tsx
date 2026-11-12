"use client";

import { useEffect } from "react";

export default function ErrorPage({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error(error);
  }, [error]);
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center px-6 text-center">
      <h1 className="text-xl font-bold">Oups, une erreur est survenue</h1>
      <p className="mt-2 max-w-sm text-sm text-gray-500">{error.message || "Erreur inattendue."}</p>
      <button
        type="button"
        onClick={reset}
        className="mt-6 inline-flex h-11 items-center rounded-xl bg-brand-600 px-5 font-semibold text-white"
      >
        Réessayer
      </button>
    </main>
  );
}
