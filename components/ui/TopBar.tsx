"use client";

import { ChevronLeft } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { ReactNode } from "react";

const backClasses =
  "-ml-2 flex h-10 w-10 items-center justify-center rounded-full text-brand-600 hover:bg-gray-100 dark:text-brand-300 dark:hover:bg-gray-800";

/**
 * Barre de titre collante en haut de page (respecte l'encoche iOS).
 * back : true → router.back(), ou une URL de repli. onBack : action personnalisée (prioritaire).
 */
export function TopBar({
  title,
  back,
  onBack,
  right,
  subtitle,
}: {
  title: string;
  back?: boolean | string;
  /** action de retour personnalisée (prioritaire sur back) */
  onBack?: () => void;
  right?: ReactNode;
  subtitle?: string;
}) {
  const router = useRouter();
  const backButton = onBack ? (
    <button type="button" aria-label="Retour" onClick={onBack} className={backClasses}>
      <ChevronLeft className="h-6 w-6" />
    </button>
  ) : back === undefined || back === false ? null : typeof back === "string" ? (
    <Link href={back} aria-label="Retour" className={backClasses}>
      <ChevronLeft className="h-6 w-6" />
    </Link>
  ) : (
    <button
      type="button"
      aria-label="Retour"
      onClick={() => (window.history.length > 1 ? router.back() : router.push("/"))}
      className={backClasses}
    >
      <ChevronLeft className="h-6 w-6" />
    </button>
  );

  return (
    <header className="sticky top-0 z-30 border-b border-gray-200/70 bg-gray-50/85 backdrop-blur-md dark:border-gray-800 dark:bg-[#0b0b0f]/85">
      <div className="mx-auto flex h-14 max-w-2xl items-center gap-2 px-4" style={{ marginTop: "env(safe-area-inset-top)" }}>
        {backButton}
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-lg font-bold leading-tight text-gray-900 dark:text-gray-100">{title}</h1>
          {subtitle && <p className="truncate text-xs text-gray-500 dark:text-gray-400">{subtitle}</p>}
        </div>
        {right && <div className="flex shrink-0 items-center gap-1">{right}</div>}
      </div>
    </header>
  );
}

/** Conteneur de page standard (largeur max, marges, espace pour la barre du bas). */
export function Page({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <main className={`mx-auto w-full max-w-2xl px-4 pb-8 pt-4 ${className}`}>{children}</main>;
}
