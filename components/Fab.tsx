"use client";

import { Plus } from "lucide-react";
import Link from "next/link";

/** Bouton flottant "+" au-dessus de la barre de navigation. */
export function Fab({ href = "/rdv/new", label = "Nouveau rendez-vous" }: { href?: string; label?: string }) {
  return (
    <Link
      href={href}
      aria-label={label}
      title={label}
      className="fixed right-5 z-40 flex h-14 w-14 items-center justify-center rounded-full bg-brand-600 text-white shadow-fab transition hover:bg-brand-700 active:scale-95"
      style={{ bottom: "calc(5rem + env(safe-area-inset-bottom))" }}
    >
      <Plus className="h-7 w-7" strokeWidth={2.5} />
    </Link>
  );
}
