/** Nom d'utilisateur SeeU : unique, en minuscules, toujours affiché avec un « @ » devant. */

export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;
/** Même règle que la contrainte SQL profiles_username_format. */
export const USERNAME_RE = /^[a-z0-9][a-z0-9_.]{2,19}$/;

export const USERNAME_HINT = "3 à 20 caractères : lettres minuscules, chiffres, point et tiret bas.";

/** Nettoie une saisie au fil de la frappe : retire le « @ », les accents, les espaces et les caractères interdits. */
export function normalizeUsername(raw: string): string {
  return raw
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9_.]/g, "")
    .slice(0, USERNAME_MAX);
}

/** Message d'erreur si le format est invalide, sinon null. */
export function usernameFormatError(value: string): string | null {
  if (value.length < USERNAME_MIN) return `Au moins ${USERNAME_MIN} caractères.`;
  if (!/^[a-z0-9]/.test(value)) return "Doit commencer par une lettre ou un chiffre.";
  if (!USERNAME_RE.test(value)) return USERNAME_HINT;
  return null;
}

/** « @andrea » (ou chaîne vide si pas encore de nom d'utilisateur). */
export function handle(username: string | null | undefined): string {
  return username ? `@${username}` : "";
}

/** Proposition de départ à partir d'un prénom ou d'un email. */
export function suggestUsername(source: string | null | undefined): string {
  const base = normalizeUsername((source ?? "").split("@")[0].replace(/\s+/g, "."));
  return base.replace(/^[_.]+/, "");
}
