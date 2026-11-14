import type { ReactNode } from "react";

/** Habillage commun des écrans d'authentification (logo, titre, accroche). */
export function AuthShell({
  children,
  title = "SeeU",
  subtitle = "Ne plus oublier les personnes qu'on aimerait revoir.",
}: {
  children: ReactNode;
  title?: string;
  subtitle?: string;
}) {
  return (
    <main
      className="flex min-h-dvh flex-col items-center justify-center px-5"
      style={{ paddingTop: "max(2.5rem, env(safe-area-inset-top))", paddingBottom: "max(2.5rem, env(safe-area-inset-bottom))" }}
    >
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center text-center">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/icons/icon-192.png" alt="SeeU" width={72} height={72} className="h-[72px] w-[72px] rounded-2xl shadow-lg" />
          <h1 className="mt-4 text-2xl font-bold text-gray-900 dark:text-gray-100">{title}</h1>
          <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{subtitle}</p>
        </div>
        {children}
        <p className="mt-8 text-center text-xs text-gray-400 dark:text-gray-500">
          Vos données sont privées : chaque compte est totalement isolé.
        </p>
      </div>
    </main>
  );
}
