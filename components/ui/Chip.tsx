"use client";

import type { ButtonHTMLAttributes } from "react";

export function Chip({
  active = false,
  className = "",
  children,
  type = "button",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { active?: boolean }) {
  return (
    <button
      type={type}
      aria-pressed={active}
      className={`inline-flex h-9 shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border px-3.5 text-sm font-medium transition active:scale-95 ${
        active
          ? "border-brand-600 bg-brand-600 text-white"
          : "border-gray-300 bg-white text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200 dark:hover:bg-gray-800"
      } ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}

/** Rangée de chips défilante horizontalement. */
export function ChipRow({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`no-scrollbar -mx-4 flex gap-2 overflow-x-auto px-4 py-1 ${className}`}>{children}</div>;
}
