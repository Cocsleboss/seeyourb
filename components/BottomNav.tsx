"use client";

import { Clock, Home, Settings, Users } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/", label: "Accueil", icon: Home, match: (p: string) => p === "/" },
  { href: "/contacts", label: "Contacts", icon: Users, match: (p: string) => p.startsWith("/contacts") },
  { href: "/history", label: "Historique", icon: Clock, match: (p: string) => p.startsWith("/history") },
  { href: "/settings", label: "Réglages", icon: Settings, match: (p: string) => p.startsWith("/settings") },
];

export function BottomNav() {
  const pathname = usePathname() || "/";
  return (
    <nav
      aria-label="Navigation principale"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-gray-200/80 bg-white/90 pb-[env(safe-area-inset-bottom)] backdrop-blur-md dark:border-gray-800 dark:bg-[#0b0b0f]/90"
    >
      <div className="mx-auto flex h-16 max-w-2xl items-stretch">
        {TABS.map(({ href, label, icon: Icon, match }) => {
          const active = match(pathname);
          return (
            <Link
              key={href}
              href={href}
              aria-current={active ? "page" : undefined}
              className={`flex flex-1 flex-col items-center justify-center gap-0.5 text-[11px] font-medium transition active:scale-95 ${
                active ? "text-brand-600 dark:text-brand-300" : "text-gray-500 dark:text-gray-400"
              }`}
            >
              <Icon className="h-6 w-6" strokeWidth={active ? 2.4 : 2} />
              {label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
