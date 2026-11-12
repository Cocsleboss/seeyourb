/** Normalise pour la recherche : minuscules, sans accents, sans espaces superflus. */
export function normalizeText(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

export function matchesQuery(haystack: string | null | undefined, query: string): boolean {
  if (!query.trim()) return true;
  if (!haystack) return false;
  return normalizeText(haystack).includes(normalizeText(query));
}

/** plural(3, "contact") → "3 contacts" ; plural(1, "rendez-vous", "rendez-vous") → "1 rendez-vous" */
export function plural(n: number, singular: string, pluralForm?: string): string {
  return `${n} ${n > 1 ? (pluralForm ?? singular + "s") : singular}`;
}
