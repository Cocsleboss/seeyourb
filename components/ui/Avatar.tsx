"use client";

import { useSignedUrl } from "@/lib/hooks";

const PALETTE = [
  "bg-rose-200 text-rose-900",
  "bg-orange-200 text-orange-900",
  "bg-amber-200 text-amber-900",
  "bg-lime-200 text-lime-900",
  "bg-emerald-200 text-emerald-900",
  "bg-teal-200 text-teal-900",
  "bg-sky-200 text-sky-900",
  "bg-indigo-200 text-indigo-900",
  "bg-violet-200 text-violet-900",
  "bg-fuchsia-200 text-fuchsia-900",
];

export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function colorFor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return PALETTE[h % PALETTE.length];
}

export function Avatar({
  name,
  path,
  src,
  size = 44,
  className = "",
}: {
  name: string;
  /** chemin dans le bucket privé "photos" */
  path?: string | null;
  /** URL directe (prévisualisation locale) — prioritaire sur path */
  src?: string | null;
  size?: number;
  className?: string;
}) {
  const signed = useSignedUrl(src ? null : path);
  const url = src || signed;
  const style = { width: size, height: size, fontSize: Math.max(11, Math.round(size * 0.38)) };
  if (url) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={url}
        alt={name}
        style={style}
        className={`shrink-0 rounded-full object-cover ${className}`}
        loading="lazy"
      />
    );
  }
  return (
    <div
      style={style}
      aria-hidden
      className={`flex shrink-0 select-none items-center justify-center rounded-full font-semibold ${colorFor(name)} ${className}`}
    >
      {initials(name)}
    </div>
  );
}

/** Pile d'avatars qui se chevauchent (participants d'un rendez-vous). */
export function AvatarStack({
  people,
  size = 28,
  max = 4,
}: {
  people: { id: string; name: string; photo_path?: string | null }[];
  size?: number;
  max?: number;
}) {
  const shown = people.slice(0, max);
  const rest = people.length - shown.length;
  return (
    <div className="flex items-center">
      {shown.map((p, i) => (
        <div key={p.id} className={i > 0 ? "-ml-2" : ""}>
          <Avatar name={p.name} path={p.photo_path} size={size} className="ring-2 ring-white dark:ring-gray-900" />
        </div>
      ))}
      {rest > 0 && (
        <div
          style={{ width: size, height: size, fontSize: Math.round(size * 0.4) }}
          className="-ml-2 flex items-center justify-center rounded-full bg-gray-200 font-semibold text-gray-700 ring-2 ring-white dark:bg-gray-700 dark:text-gray-200 dark:ring-gray-900"
        >
          +{rest}
        </div>
      )}
    </div>
  );
}
