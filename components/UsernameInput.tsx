"use client";

import { Check, X } from "lucide-react";
import { useEffect, useState } from "react";
import { Field, Input, Spinner } from "@/components/ui";
import { usernameAvailable } from "@/lib/data";
import { USERNAME_HINT, USERNAME_MAX, normalizeUsername, usernameFormatError } from "@/lib/username";

export type UsernameState = "empty" | "invalid" | "checking" | "available" | "taken" | "unchanged" | "unknown";

/**
 * Champ « nom d'utilisateur » avec le « @ » devant : nettoie la saisie au fil de la frappe
 * et vérifie en direct que le nom est libre. `onState` indique si on peut enregistrer
 * ("available" ou "unchanged" ; "unknown" = vérification impossible, la base tranchera).
 */
export function UsernameInput({
  id = "username",
  label = "Nom d'utilisateur",
  value,
  onChange,
  onState,
  current,
  required,
  autoFocus,
  disabled,
}: {
  id?: string;
  label?: string;
  value: string;
  onChange: (v: string) => void;
  onState?: (s: UsernameState) => void;
  /** nom d'utilisateur actuel de la personne (pas de vérification s'il est inchangé) */
  current?: string | null;
  required?: boolean;
  autoFocus?: boolean;
  disabled?: boolean;
}) {
  const [state, setState] = useState<UsernameState>("empty");

  useEffect(() => {
    let alive = true;
    const set = (s: UsernameState) => {
      if (!alive) return;
      setState(s);
      onState?.(s);
    };
    if (!value) set("empty");
    else if (current && value === current) set("unchanged");
    else if (usernameFormatError(value)) set("invalid");
    else {
      set("checking");
      const t = setTimeout(() => {
        usernameAvailable(value)
          .then((free) => set(free ? "available" : "taken"))
          .catch(() => set("unknown"));
      }, 350);
      return () => {
        alive = false;
        clearTimeout(t);
      };
    }
    return () => {
      alive = false;
    };
  }, [value, current]); // eslint-disable-line react-hooks/exhaustive-deps

  const error = state === "taken" ? "Ce nom d'utilisateur est déjà pris." : state === "invalid" && value.length > 0 ? usernameFormatError(value) : null;
  const hint = state === "available" ? `@${value} est disponible` : USERNAME_HINT;

  return (
    <Field label={label} htmlFor={id} required={required} error={error} hint={hint}>
      <div className="relative">
        <span className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[16px] font-semibold text-gray-400">@</span>
        <Input
          id={id}
          value={value}
          onChange={(e) => onChange(normalizeUsername(e.target.value))}
          autoCapitalize="none"
          autoCorrect="off"
          autoComplete="username"
          spellCheck={false}
          maxLength={USERNAME_MAX + 1}
          placeholder="votre.nom"
          className="pl-9 pr-10"
          required={required}
          autoFocus={autoFocus}
          disabled={disabled}
          aria-invalid={error ? true : undefined}
        />
        <span className="absolute right-3 top-1/2 -translate-y-1/2">
          {state === "checking" && <Spinner className="h-4 w-4" />}
          {state === "available" && <Check className="h-5 w-5 text-emerald-600" aria-label="Disponible" />}
          {state === "taken" && <X className="h-5 w-5 text-red-500" aria-label="Déjà pris" />}
        </span>
      </div>
    </Field>
  );
}

/** Vrai si l'état du champ permet d'enregistrer. */
export function usernameOk(state: UsernameState): boolean {
  return state === "available" || state === "unchanged" || state === "unknown";
}
