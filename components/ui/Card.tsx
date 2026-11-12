import type { HTMLAttributes, ReactNode } from "react";

export function Card({ className = "", children, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-2xl border border-gray-200/70 bg-white p-4 shadow-card dark:border-gray-800 dark:bg-gray-900 ${className}`}
      {...props}
    >
      {children}
    </div>
  );
}

/** Titre de section avec action optionnelle à droite. */
export function SectionTitle({
  children,
  action,
  className = "",
}: {
  children: ReactNode;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <div className={`mb-2 flex items-center justify-between gap-3 ${className}`}>
      <h2 className="text-base font-semibold text-gray-900 dark:text-gray-100">{children}</h2>
      {action}
    </div>
  );
}

/** Ligne cliquable dans une liste (style "settings"). */
export function Row({ className = "", children, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={`flex items-center gap-3 px-4 py-3 ${className}`} {...props}>
      {children}
    </div>
  );
}

/** Conteneur de lignes séparées par des traits (dans une Card p-0). */
export function RowList({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`divide-y divide-gray-100 dark:divide-gray-800 ${className}`}>{children}</div>;
}
