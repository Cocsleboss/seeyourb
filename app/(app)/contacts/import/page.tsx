"use client";

import { BookUser, Check, ChevronLeft, FileText, ShieldCheck, Smartphone, Users, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { CategoryPicker } from "@/components/contacts/CategoryPicker";
import { FrequencyPicker } from "@/components/contacts/FrequencyPicker";
import {
  Avatar,
  Button,
  Card,
  EmptyState,
  Field,
  IconButton,
  Input,
  Page,
  Row,
  RowList,
  Sheet,
  TopBar,
  useToast,
} from "@/components/ui";
import { contactPickerSupported, dedupeImported, pickPhoneContacts, type ImportedContact } from "@/lib/contact-import";
import { createContacts, listContacts } from "@/lib/data";
import { formatDate, frequencyLabel, todayISO } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { plural } from "@/lib/text";
import type { ContactInput, FrequencyUnit } from "@/lib/types";
import { readVcfFiles } from "@/lib/vcard";

type Step = "source" | "review" | "summary";

interface Decision {
  include: boolean;
  frequency_value: number;
  frequency_unit: FrequencyUnit;
  category: string | null;
  last_meeting_date: string;
}

type Defaults = Pick<Decision, "frequency_value" | "frequency_unit" | "category">;

const STEP_LABEL: Record<Step, string> = {
  source: "Étape 1 sur 3 · Source",
  review: "Étape 2 sur 3 · Passer en revue",
  summary: "Étape 3 sur 3 · Confirmer",
};

/**
 * Import de contacts depuis le téléphone (sélecteur natif ou fichier .vcf),
 * puis revue un par un : fréquence, catégorie, dernière rencontre, ajouter / ignorer.
 * Rien n'est enregistré avant la confirmation finale.
 */
export default function ImportContactsPage() {
  const router = useRouter();
  const toast = useToast();
  const { data: existing, loading: loadingExisting, error: existingError, reload } = useAsyncData(listContacts, []);

  const [step, setStep] = useState<Step>("source");
  const [candidates, setCandidates] = useState<ImportedContact[]>([]);
  const [skipped, setSkipped] = useState({ alreadyThere: 0, duplicates: 0 });
  const [decisions, setDecisions] = useState<Record<string, Decision>>({});
  const [index, setIndex] = useState(0);
  const [saving, setSaving] = useState(false);
  /** derniers réglages choisis : pré-remplissent la fiche suivante */
  const defaultsRef = useRef<Defaults>({ frequency_value: 1, frequency_unit: "months", category: null });

  const ingest = (list: ImportedContact[]) => {
    const { fresh, alreadyThere, duplicates } = dedupeImported(list, existing ?? []);
    if (!fresh.length) {
      toast.info(list.length ? "Ces contacts sont déjà dans SeeYourB." : "Aucun contact trouvé.");
      return;
    }
    setCandidates(fresh);
    setSkipped({ alreadyThere, duplicates });
    setDecisions({});
    setIndex(0);
    setStep("review");
  };

  const decide = (key: string, d: Decision) => {
    setDecisions((prev) => ({ ...prev, [key]: d }));
    if (d.include) defaultsRef.current = { frequency_value: d.frequency_value, frequency_unit: d.frequency_unit, category: d.category };
    if (index + 1 < candidates.length) setIndex(index + 1);
    else setStep("summary");
  };

  /** Termine la revue : les contacts restants (à partir du courant) sont tous ajoutés avec `template`, ou tous ignorés. */
  const finishRemaining = (template: Decision | null) => {
    setDecisions((prev) => {
      const next = { ...prev };
      for (const c of candidates.slice(index)) {
        next[c.key] = template
          ? { ...template }
          : { ...(prev[c.key] ?? { ...defaultsRef.current, last_meeting_date: todayISO() }), include: false };
      }
      return next;
    });
    if (template) defaultsRef.current = { frequency_value: template.frequency_value, frequency_unit: template.frequency_unit, category: template.category };
    setStep("summary");
  };

  const toAdd = candidates.filter((c) => decisions[c.key]?.include);

  const save = async () => {
    setSaving(true);
    try {
      const inputs: ContactInput[] = toAdd.map((c) => {
        const d = decisions[c.key];
        return {
          name: c.name,
          phone: c.phone,
          email: c.email,
          birthday: c.birthday,
          notes: c.notes,
          category: d.category,
          last_meeting_date: d.last_meeting_date,
          frequency_value: d.frequency_value,
          frequency_unit: d.frequency_unit,
        };
      });
      const created = await createContacts(inputs);
      toast.success(plural(created.length, "contact ajouté", "contacts ajoutés"));
      router.replace("/contacts");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Import impossible");
      // Si une partie a été enregistrée, on la retire de la sélection pour éviter les doublons au prochain essai.
      try {
        const now = await listContacts();
        const { fresh } = dedupeImported(candidates, now);
        if (fresh.length !== candidates.length) {
          setCandidates(fresh);
          setIndex(0);
          if (!fresh.some((c) => decisions[c.key]?.include)) router.replace("/contacts");
        }
      } catch {
        /* ignore */
      }
    } finally {
      setSaving(false);
    }
  };

  const goBack = () => {
    if (step === "source") router.push("/contacts");
    else if (step === "review") {
      if (index > 0) setIndex(index - 1);
      else setStep("source");
    } else setStep("review");
  };

  const current = candidates[index];
  const skippedTotal = skipped.alreadyThere + skipped.duplicates;

  return (
    <>
      <TopBar title="Importer des contacts" onBack={goBack} subtitle={STEP_LABEL[step]} />
      <Page className="space-y-4">
        {step === "source" && (
          <SourceStep
            disabled={loadingExisting || Boolean(existingError)}
            error={existingError}
            onRetry={() => reload(false)}
            onLoaded={ingest}
          />
        )}

        {step === "review" && current && (
          <>
            <div className="space-y-1.5">
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-800">
                <div className="h-full rounded-full bg-brand-600 transition-all" style={{ width: `${Math.round((index / candidates.length) * 100)}%` }} />
              </div>
              <div className="flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
                <span>
                  Contact {index + 1} sur {candidates.length}
                </span>
                {skippedTotal > 0 && (
                  <span title="Déjà présents dans SeeYourB ou en double dans la sélection">
                    {plural(skippedTotal, "écarté")}
                  </span>
                )}
              </div>
            </div>
            <ReviewCard
              key={current.key}
              contact={current}
              remaining={candidates.length - index}
              initial={decisions[current.key] ?? { include: true, ...defaultsRef.current, last_meeting_date: todayISO() }}
              onDecide={(d) => decide(current.key, d)}
              onFinishRemaining={finishRemaining}
            />
          </>
        )}

        {step === "summary" && (
          <>
            {toAdd.length ? (
              <Card className="overflow-hidden p-0">
                <div className="border-b border-gray-100 px-4 py-3 dark:border-gray-800">
                  <p className="font-semibold text-gray-900 dark:text-gray-100">{plural(toAdd.length, "contact")} à ajouter</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {candidates.length - toAdd.length > 0
                      ? `${plural(candidates.length - toAdd.length, "ignoré")} · `
                      : ""}
                    Vous pourrez tout modifier ensuite depuis chaque fiche.
                  </p>
                </div>
                <RowList>
                  {toAdd.map((c) => {
                    const d = decisions[c.key];
                    return (
                      <Row key={c.key}>
                        <Avatar name={c.name} size={40} />
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] font-medium text-gray-900 dark:text-gray-100">{c.name}</p>
                          <p className="truncate text-xs text-gray-500 dark:text-gray-400">
                            {frequencyLabel(d.frequency_value, d.frequency_unit)}
                            {d.category ? ` · ${d.category}` : ""}
                          </p>
                        </div>
                        <IconButton
                          label={`Retirer ${c.name}`}
                          onClick={() => setDecisions((prev) => ({ ...prev, [c.key]: { ...prev[c.key], include: false } }))}
                        >
                          <X className="h-5 w-5" />
                        </IconButton>
                      </Row>
                    );
                  })}
                </RowList>
              </Card>
            ) : (
              <EmptyState
                icon={<Users className="h-7 w-7" />}
                title="Aucun contact sélectionné"
                description="Revenez en arrière pour en ajouter, ou recommencez avec une autre sélection."
              />
            )}
            <Button full size="lg" loading={saving} disabled={!toAdd.length} onClick={save}>
              <Check className="h-5 w-5" /> Importer {plural(toAdd.length, "contact")}
            </Button>
            <Button
              variant="secondary"
              full
              disabled={saving}
              onClick={() => {
                setIndex(0);
                setStep("review");
              }}
            >
              Revoir la sélection
            </Button>
          </>
        )}
      </Page>
    </>
  );
}

/* ------------------------------------------------------------------ */
/*  Étape 1 : source                                                    */
/* ------------------------------------------------------------------ */

function SourceStep({
  disabled,
  error,
  onRetry,
  onLoaded,
}: {
  disabled: boolean;
  error: string | null;
  onRetry: () => void;
  onLoaded: (list: ImportedContact[]) => void;
}) {
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const [supported, setSupported] = useState<boolean | null>(null);
  const [busy, setBusy] = useState<"picker" | "file" | null>(null);

  useEffect(() => setSupported(contactPickerSupported()), []);

  const fromPhone = async () => {
    setBusy("picker");
    try {
      const list = await pickPhoneContacts();
      if (list.length) onLoaded(list);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Sélection impossible");
    } finally {
      setBusy(null);
    }
  };

  const fromFiles = async (files: File[]) => {
    setBusy("file");
    try {
      const list = await readVcfFiles(files);
      if (!list.length) toast.info("Aucun contact lisible dans ce fichier.");
      else onLoaded(list);
    } catch {
      toast.error("Fichier illisible. Exportez vos contacts au format vCard (.vcf).");
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      {error && (
        <Card className="space-y-3 border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/20">
          <p className="text-sm text-red-700 dark:text-red-200">{error}</p>
          <Button variant="secondary" onClick={onRetry}>
            Réessayer
          </Button>
        </Card>
      )}

      <Card className="space-y-4">
        <div className="flex items-start gap-3">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600 dark:bg-gray-800 dark:text-brand-300">
            <Smartphone className="h-6 w-6" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900 dark:text-gray-100">Depuis le carnet d&apos;adresses</h3>
            <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
              Le sélecteur de votre téléphone s&apos;ouvre : cochez une, plusieurs ou toutes les personnes. Vous choisirez
              ensuite, pour chacune, la fréquence et si vous l&apos;ajoutez ou non.
            </p>
          </div>
        </div>
        {supported === false ? (
          <p className="rounded-xl bg-gray-50 px-3 py-2 text-xs text-gray-600 dark:bg-gray-800 dark:text-gray-300">
            Non disponible dans ce navigateur. Sur iPhone, ouvrez SeeYourB dans Safari ; sur Android, dans Chrome. Sinon,
            utilisez un fichier .vcf ci-dessous.
          </p>
        ) : (
          <Button full size="lg" onClick={fromPhone} loading={busy === "picker"} disabled={disabled || busy !== null || supported === null}>
            <BookUser className="h-5 w-5" /> Choisir dans mes contacts
          </Button>
        )}
      </Card>

      <Card className="space-y-4">
        <div className="flex items-start gap-3">
          <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600 dark:bg-gray-800 dark:text-brand-300">
            <FileText className="h-6 w-6" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-900 dark:text-gray-100">Depuis un fichier .vcf (vCard)</h3>
            <p className="mt-0.5 text-sm text-gray-500 dark:text-gray-400">
              Fonctionne partout, idéal pour importer tout le carnet d&apos;un coup. Exportez vos contacts puis ouvrez le fichier ici.
            </p>
          </div>
        </div>
        <input
          ref={fileRef}
          type="file"
          accept=".vcf,text/vcard,text/x-vcard,text/directory"
          multiple
          className="hidden"
          onChange={(e) => {
            const files = Array.from(e.target.files ?? []);
            e.target.value = "";
            if (files.length) fromFiles(files);
          }}
        />
        <Button variant="secondary" full size="lg" onClick={() => fileRef.current?.click()} loading={busy === "file"} disabled={disabled || busy !== null}>
          <FileText className="h-5 w-5" /> Ouvrir un fichier .vcf
        </Button>
        <details className="text-sm text-gray-600 dark:text-gray-300">
          <summary className="cursor-pointer font-medium text-brand-600 dark:text-brand-300">Comment exporter mes contacts en .vcf ?</summary>
          <ul className="mt-2 list-disc space-y-1.5 pl-5">
            <li>
              <span className="font-medium">iPhone, tout le carnet</span> : sur un ordinateur, icloud.com → Contacts → tout
              sélectionner → ⚙ → <em>Exporter vCard</em>. Envoyez-vous le fichier (Mail, AirDrop, Fichiers).
            </li>
            <li>
              <span className="font-medium">iPhone, quelques fiches</span> : app Contacts → ouvrir la fiche → <em>Partager le contact</em> →{" "}
              <em>Enregistrer dans Fichiers</em>.
            </li>
            <li>
              <span className="font-medium">Android</span> : app Contacts → menu ⋮ ou Réglages → <em>Exporter</em> → fichier .vcf.
            </li>
            <li>
              <span className="font-medium">Google Contacts</span> : contacts.google.com → Exporter → vCard.
            </li>
          </ul>
        </details>
      </Card>

      <p className="flex items-start gap-2 px-1 text-xs text-gray-500 dark:text-gray-400">
        <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0" />
        La lecture se fait sur votre appareil. Seuls les contacts que vous validez à la dernière étape sont enregistrés dans votre
        espace privé ; les personnes déjà présentes sont écartées automatiquement.
      </p>
    </>
  );
}

/* ------------------------------------------------------------------ */
/*  Étape 2 : fiche à passer en revue                                   */
/* ------------------------------------------------------------------ */

function ReviewCard({
  contact,
  remaining,
  initial,
  onDecide,
  onFinishRemaining,
}: {
  contact: ImportedContact;
  /** nombre de contacts restants, celui-ci compris */
  remaining: number;
  initial: Decision;
  onDecide: (d: Decision) => void;
  onFinishRemaining: (template: Decision | null) => void;
}) {
  const [freqValue, setFreqValue] = useState(initial.frequency_value);
  const [freqUnit, setFreqUnit] = useState<FrequencyUnit>(initial.frequency_unit);
  const [category, setCategory] = useState<string | null>(initial.category);
  const [lastMeeting, setLastMeeting] = useState(initial.last_meeting_date);
  const [bulkOpen, setBulkOpen] = useState(false);

  const freqValid = Number.isInteger(freqValue) && freqValue >= 1;
  const dateValid = Boolean(lastMeeting) && lastMeeting <= todayISO();
  const valid = freqValid && dateValid;
  const current = (): Decision => ({ include: true, frequency_value: freqValue, frequency_unit: freqUnit, category, last_meeting_date: lastMeeting });

  const details = [contact.phone, contact.email].filter(Boolean).join(" · ");

  return (
    <>
      <Card className="space-y-5">
        <div className="flex items-center gap-3">
          <Avatar name={contact.name} size={56} />
          <div className="min-w-0">
            <p className="truncate text-lg font-semibold text-gray-900 dark:text-gray-100">{contact.name}</p>
            {details && <p className="truncate text-sm text-gray-500 dark:text-gray-400">{details}</p>}
            {contact.birthday && (
              <p className="text-xs text-gray-500 dark:text-gray-400">Anniversaire : {formatDate(contact.birthday, "d MMMM yyyy")}</p>
            )}
          </div>
        </div>

        <Field label="À revoir tous les…" required error={freqValid ? null : "La fréquence doit être d'au moins 1."}>
          <FrequencyPicker
            value={freqValue}
            unit={freqUnit}
            onChange={(v, u) => {
              setFreqValue(v);
              setFreqUnit(u);
            }}
          />
        </Field>

        <Field label="Catégorie">
          <CategoryPicker value={category} onChange={setCategory} />
        </Field>

        <Field
          label="Dernière fois que vous l'avez vu(e)"
          htmlFor={`last-${contact.key}`}
          required
          error={dateValid ? null : "Indiquez une date passée ou aujourd'hui."}
        >
          <Input id={`last-${contact.key}`} type="date" value={lastMeeting} max={todayISO()} onChange={(e) => setLastMeeting(e.target.value)} />
        </Field>

        <div className="flex gap-3">
          <Button variant="secondary" full size="lg" onClick={() => onDecide({ ...current(), include: false })}>
            <X className="h-5 w-5" /> Ignorer
          </Button>
          <Button full size="lg" disabled={!valid} onClick={() => onDecide(current())}>
            <Check className="h-5 w-5" /> Ajouter
          </Button>
        </div>
      </Card>

      {remaining > 1 && (
        <div className="flex justify-center">
          <Button variant="ghost" size="sm" onClick={() => setBulkOpen(true)}>
            Les {remaining} restants d&apos;un coup…
          </Button>
        </div>
      )}

      <Sheet open={bulkOpen} onClose={() => setBulkOpen(false)} title="Contacts restants">
        <p className="text-[15px] text-gray-600 dark:text-gray-300">
          Il reste {plural(remaining, "contact")} à passer en revue, celui-ci compris.
        </p>
        <div className="mt-5 space-y-2">
          <Button
            full
            disabled={!valid}
            onClick={() => {
              setBulkOpen(false);
              onFinishRemaining(current());
            }}
          >
            Tout ajouter · {frequencyLabel(freqValue, freqUnit)}
            {category ? ` · ${category}` : ""}
          </Button>
          <Button
            variant="secondary"
            full
            onClick={() => {
              setBulkOpen(false);
              onFinishRemaining(null);
            }}
          >
            Tout ignorer et terminer
          </Button>
          <p className="pt-1 text-center text-xs text-gray-500 dark:text-gray-400">
            Vous pourrez encore retirer des contacts à l&apos;étape suivante.
          </p>
        </div>
      </Sheet>

      <p className="flex items-center justify-center gap-1 text-xs text-gray-400">
        <ChevronLeft className="h-3.5 w-3.5" /> La flèche en haut revient au contact précédent
      </p>
    </>
  );
}
