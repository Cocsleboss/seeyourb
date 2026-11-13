/**
 * Import de contacts depuis le téléphone.
 *
 * Deux sources, toutes deux lues côté navigateur (rien ne part vers un serveur
 * avant validation explicite de l'utilisateur) :
 *  - l'API Contact Picker (navigator.contacts) : sélecteur natif, Chrome Android / Safari iOS ;
 *  - un fichier vCard (.vcf) exporté depuis l'app Contacts (voir lib/vcard.ts).
 *
 * Une PWA n'a jamais d'accès permanent au carnet d'adresses : il s'agit donc d'un
 * import ponctuel, pas d'une synchronisation en continu.
 */
import { normalizeText } from "@/lib/text";
import type { Contact } from "@/lib/types";

export interface ImportedContact {
  /** identifiant local, stable le temps de l'import */
  key: string;
  name: string;
  phone: string | null;
  email: string | null;
  /** YYYY-MM-DD */
  birthday: string | null;
  notes: string | null;
}

let seq = 0;
export function nextImportKey(): string {
  return `imp-${++seq}`;
}

/* ------------------------------------------------------------------ */
/*  Nettoyage des champs                                                */
/* ------------------------------------------------------------------ */

export function cleanPhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let s = raw.trim().replace(/^tel:/i, "");
  s = s.split(";")[0]; // "tel:+33...;ext=12" → sans extension
  s = s.replace(/\s+/g, " ").trim();
  if (!/\d/.test(s)) return null;
  return s.slice(0, 40);
}

export function cleanEmail(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const s = raw.trim().replace(/^mailto:/i, "").toLowerCase();
  if (!/^\S+@\S+\.\S+$/.test(s)) return null;
  return s.slice(0, 120);
}

/* ------------------------------------------------------------------ */
/*  Détection des doublons                                              */
/* ------------------------------------------------------------------ */

/** Clé de comparaison d'un numéro : chiffres seuls, 9 derniers (06 12… ≡ +33 6 12…). */
export function phoneKey(phone: string | null | undefined): string | null {
  if (!phone) return null;
  let digits = phone.replace(/\D/g, "");
  if (digits.startsWith("00")) digits = digits.slice(2);
  if (digits.length < 6) return null;
  return digits.length > 9 ? digits.slice(-9) : digits;
}

export function nameKey(name: string): string {
  return normalizeText(name).replace(/\s+/g, " ");
}

export function emailKey(email: string | null | undefined): string | null {
  const e = email?.trim().toLowerCase();
  return e || null;
}

export interface DedupeResult {
  /** contacts nouveaux, à proposer à l'utilisateur */
  fresh: ImportedContact[];
  /** déjà présents dans SeeYourB (même nom, numéro ou email) */
  alreadyThere: number;
  /** doublons à l'intérieur de la sélection elle-même */
  duplicates: number;
}

export function dedupeImported(
  list: ImportedContact[],
  existing: Pick<Contact, "name" | "phone" | "email">[]
): DedupeResult {
  const appNames = new Set(existing.map((c) => nameKey(c.name)));
  const appPhones = new Set(existing.map((c) => phoneKey(c.phone)).filter((k): k is string => Boolean(k)));
  const appEmails = new Set(existing.map((c) => emailKey(c.email)).filter((k): k is string => Boolean(k)));
  const seenNames = new Set<string>();
  const seenPhones = new Set<string>();
  const seenEmails = new Set<string>();

  const fresh: ImportedContact[] = [];
  let alreadyThere = 0;
  let duplicates = 0;

  for (const c of list) {
    const nk = nameKey(c.name);
    const pk = phoneKey(c.phone);
    const ek = emailKey(c.email);
    if (appNames.has(nk) || (pk && appPhones.has(pk)) || (ek && appEmails.has(ek))) {
      alreadyThere++;
      continue;
    }
    if (seenNames.has(nk) || (pk && seenPhones.has(pk)) || (ek && seenEmails.has(ek))) {
      duplicates++;
      continue;
    }
    seenNames.add(nk);
    if (pk) seenPhones.add(pk);
    if (ek) seenEmails.add(ek);
    fresh.push(c);
  }
  return { fresh, alreadyThere, duplicates };
}

/* ------------------------------------------------------------------ */
/*  Contact Picker API (navigator.contacts)                             */
/* ------------------------------------------------------------------ */

interface PickerContact {
  name?: string[];
  tel?: string[];
  email?: string[];
}

interface ContactsManager {
  select(properties: string[], options?: { multiple?: boolean }): Promise<PickerContact[]>;
  getProperties?(): Promise<string[]>;
}

declare global {
  interface Navigator {
    contacts?: ContactsManager;
  }
}

/** true si le navigateur propose le sélecteur natif de contacts (Chrome Android, Safari iOS…). */
export function contactPickerSupported(): boolean {
  if (typeof navigator === "undefined") return false;
  const cm = navigator.contacts;
  return Boolean(cm && typeof cm.select === "function");
}

/**
 * Ouvre le sélecteur natif (à appeler depuis un clic utilisateur).
 * Renvoie une liste vide si l'utilisateur annule.
 */
export async function pickPhoneContacts(): Promise<ImportedContact[]> {
  const cm = typeof navigator !== "undefined" ? navigator.contacts : undefined;
  if (!cm) throw new Error("La sélection de contacts n'est pas disponible dans ce navigateur.");
  let picked: PickerContact[];
  try {
    picked = await cm.select(["name", "tel", "email"], { multiple: true });
  } catch (e) {
    const name = e instanceof Error ? e.name : "";
    if (name === "InvalidStateError") throw new Error("Un sélecteur de contacts est déjà ouvert.");
    if (name === "SecurityError")
      throw new Error("Le navigateur a bloqué l'accès aux contacts. Réessayez en appuyant directement sur le bouton.");
    throw new Error("Impossible d'ouvrir vos contacts sur cet appareil. Utilisez l'import d'un fichier .vcf.");
  }
  return (picked ?? []).map(fromPicker).filter((c): c is ImportedContact => c !== null);
}

function fromPicker(p: PickerContact): ImportedContact | null {
  const name = (p.name ?? []).map((s) => s.trim()).filter(Boolean)[0] ?? "";
  const phone = cleanPhone((p.tel ?? [])[0]);
  const email = cleanEmail((p.email ?? [])[0]);
  const finalName = name || phone || email;
  if (!finalName) return null;
  return { key: nextImportKey(), name: finalName.slice(0, 120), phone, email, birthday: null, notes: null };
}
