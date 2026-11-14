/**
 * Lecture de fichiers vCard (.vcf) exportés depuis iPhone, Android, Google Contacts, Outlook…
 * Gère les versions 2.1 / 3.0 / 4.0 : pliage de lignes, quoted-printable, groupes "item1.",
 * paramètres avec ou sans "TYPE=". Seuls les champs utiles à SeeU sont extraits.
 * Les photos (base64) sont ignorées.
 */
import { cleanEmail, cleanPhone, nextImportKey, type ImportedContact } from "@/lib/contact-import";

interface Prop {
  name: string;
  params: Record<string, string[]>;
  value: string;
}

/** Lit un ou plusieurs fichiers .vcf. */
export async function readVcfFiles(files: File[]): Promise<ImportedContact[]> {
  const out: ImportedContact[] = [];
  for (const f of files) out.push(...parseVCards(await f.text()));
  return out;
}

export function parseVCards(text: string): ImportedContact[] {
  const cards: ImportedContact[] = [];
  let current: Prop[] | null = null;
  for (const line of unfold(text)) {
    if (!line.trim()) continue;
    if (/^BEGIN:VCARD\s*$/i.test(line)) {
      current = [];
      continue;
    }
    if (/^END:VCARD\s*$/i.test(line)) {
      if (current) {
        const c = toContact(current);
        if (c) cards.push(c);
      }
      current = null;
      continue;
    }
    if (!current) continue;
    const p = parseLine(line);
    if (p) current.push(p);
  }
  return cards;
}

/* ------------------------------------------------------------------ */
/*  Découpage                                                           */
/* ------------------------------------------------------------------ */

/** Recolle les lignes pliées (espace/tabulation en tête) et les coupures quoted-printable (« = » final). */
function unfold(text: string): string[] {
  const out: string[] = [];
  for (const line of text.replace(/\r\n?/g, "\n").split("\n")) {
    const prev = out.length ? out[out.length - 1] : null;
    if (prev !== null && (line.startsWith(" ") || line.startsWith("\t"))) {
      out[out.length - 1] = prev + line.slice(1);
    } else if (prev !== null && isQpSoftBreak(prev)) {
      out[out.length - 1] = prev.slice(0, -1) + line;
    } else {
      out.push(line);
    }
  }
  return out;
}

function isQpSoftBreak(prev: string): boolean {
  if (!prev.endsWith("=")) return false;
  const colon = prev.indexOf(":");
  const head = colon >= 0 ? prev.slice(0, colon) : prev;
  return /QUOTED-PRINTABLE/i.test(head);
}

function parseLine(line: string): Prop | null {
  // premier ':' hors guillemets
  let inQuotes = false;
  let idx = -1;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') inQuotes = !inQuotes;
    else if (ch === ":" && !inQuotes) {
      idx = i;
      break;
    }
  }
  if (idx <= 0) return null;

  const head = line.slice(0, idx);
  let value = line.slice(idx + 1);
  const parts = splitOutsideQuotes(head, ";");
  let name = parts[0].trim().toUpperCase();
  const dot = name.indexOf(".");
  if (dot >= 0) name = name.slice(dot + 1); // item1.TEL → TEL

  const params: Record<string, string[]> = {};
  for (const p of parts.slice(1)) {
    const eq = p.indexOf("=");
    const key = (eq >= 0 ? p.slice(0, eq) : "TYPE").trim().toUpperCase();
    const val = (eq >= 0 ? p.slice(eq + 1) : p).replace(/^"|"$/g, "").toUpperCase();
    (params[key] ??= []).push(...val.split(",").map((s) => s.trim()).filter(Boolean));
  }

  const enc = params.ENCODING?.[0];
  if (enc === "QUOTED-PRINTABLE") value = decodeQuotedPrintable(value, params.CHARSET?.[0]);
  else if (enc === "B" || enc === "BASE64") return null; // photos, sons… ignorés

  return { name, params, value };
}

function splitOutsideQuotes(s: string, sep: string): string[] {
  const out: string[] = [];
  let cur = "";
  let inQuotes = false;
  for (const ch of s) {
    if (ch === '"') inQuotes = !inQuotes;
    if (ch === sep && !inQuotes) {
      out.push(cur);
      cur = "";
    } else cur += ch;
  }
  out.push(cur);
  return out;
}

function decodeQuotedPrintable(s: string, charset?: string): string {
  const bytes: number[] = [];
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === "=" && /^[0-9A-Fa-f]{2}$/.test(s.slice(i + 1, i + 3))) {
      bytes.push(parseInt(s.slice(i + 1, i + 3), 16));
      i += 2;
    } else {
      bytes.push(ch.charCodeAt(0) & 0xff);
    }
  }
  const arr = new Uint8Array(bytes);
  try {
    return new TextDecoder(charset?.toLowerCase() || "utf-8").decode(arr);
  } catch {
    return new TextDecoder().decode(arr);
  }
}

/** Dés-échappe une valeur texte (vCard 3/4) : \, \; \n \\ */
function unescapeValue(v: string): string {
  return v
    .replace(/\\n/gi, "\n")
    .replace(/\\,/g, ",")
    .replace(/\;/g, ";")
    .replace(/\\\\/g, "\\")
    .trim();
}

/** Découpe une valeur structurée (N, ORG, ADR) sur les ';' non échappés. */
function splitStructured(v: string): string[] {
  return v.split(/(?<!\\);/).map(unescapeValue);
}

/* ------------------------------------------------------------------ */
/*  Extraction                                                          */
/* ------------------------------------------------------------------ */

function toContact(props: Prop[]): ImportedContact | null {
  const all = (n: string) => props.filter((p) => p.name === n);
  const first = (n: string) => all(n)[0]?.value;

  let name = first("FN") ? unescapeValue(first("FN") as string) : "";
  if (!name && first("N")) {
    const [family = "", given = "", additional = ""] = splitStructured(first("N") as string);
    name = [given, additional, family].filter(Boolean).join(" ").trim();
  }
  const org = first("ORG") ? splitStructured(first("ORG") as string).filter(Boolean).join(" · ") : "";
  const usedOrgAsName = !name && Boolean(org);
  if (!name) name = org;
  if (!name) return null;

  const phone = cleanPhone(pickPreferred(all("TEL"), ["CELL", "MOBILE", "IPHONE", "MAIN"])?.value);
  const email = cleanEmail(pickPreferred(all("EMAIL"), ["HOME", "INTERNET"])?.value);
  const birthday = parseBirthday(first("BDAY"));

  const title = first("TITLE") ? unescapeValue(first("TITLE") as string) : "";
  const note = first("NOTE") ? unescapeValue(first("NOTE") as string) : "";
  const notes = [usedOrgAsName ? "" : org, title, note].filter(Boolean).join("\n").slice(0, 2000) || null;

  return { key: nextImportKey(), name: name.replace(/\s+/g, " ").slice(0, 120), phone, email, birthday, notes };
}

/** Préférence : PREF explicite, puis un des types donnés, sinon le premier. */
function pickPreferred(list: Prop[], preferredTypes: string[]): Prop | undefined {
  if (!list.length) return undefined;
  const types = (p: Prop) => p.params.TYPE ?? [];
  const byPref = list.find((p) => types(p).includes("PREF") || "PREF" in p.params);
  if (byPref) return byPref;
  for (const t of preferredTypes) {
    const hit = list.find((p) => types(p).includes(t));
    if (hit) return hit;
  }
  return list[0];
}

/** "1990-05-14" | "19900514" | "1990-05-14T…" → YYYY-MM-DD ; sans année (--0514, 1604-…) → null. */
function parseBirthday(raw: string | undefined): string | null {
  if (!raw) return null;
  const v = raw.trim();
  const m = /^(\d{4})-?(\d{2})-?(\d{2})/.exec(v);
  if (!m) return null;
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const d = Number(m[3]);
  if (y < 1850 || mo < 1 || mo > 12 || d < 1 || d > 31) return null; // 1604 = « sans année » chez Apple
  const iso = `${m[1]}-${m[2]}-${m[3]}`;
  const date = new Date(y, mo - 1, d);
  if (date.getMonth() !== mo - 1 || date > new Date()) return null;
  return iso;
}
