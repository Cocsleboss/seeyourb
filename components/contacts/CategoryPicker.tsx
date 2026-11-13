"use client";

import { useState } from "react";
import { Chip, ChipRow, Input } from "@/components/ui";
import { CATEGORY_SUGGESTIONS } from "@/lib/types";

function isPreset(v: string | null): boolean {
  return !v || (CATEGORY_SUGGESTIONS as readonly string[]).includes(v);
}

/** Choix de la catégorie : suggestions en chips + saisie libre (« Autre… »). Émet la valeur effective (null si vide). */
export function CategoryPicker({ value, onChange }: { value: string | null; onChange: (v: string | null) => void }) {
  const [custom, setCustom] = useState(() => !isPreset(value));
  const [text, setText] = useState(() => (isPreset(value) ? "" : (value ?? "")));
  return (
    <>
      <ChipRow>
        {CATEGORY_SUGGESTIONS.map((c) => (
          <Chip
            key={c}
            active={!custom && value === c}
            onClick={() => {
              setCustom(false);
              onChange(!custom && value === c ? null : c);
            }}
          >
            {c}
          </Chip>
        ))}
        <Chip
          active={custom}
          onClick={() => {
            setCustom(true);
            onChange(text.trim() || null);
          }}
        >
          Autre…
        </Chip>
      </ChipRow>
      {custom && (
        <Input
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            onChange(e.target.value.trim() || null);
          }}
          placeholder="Ex. Voisins, Club de sport…"
          maxLength={40}
          className="mt-2"
          autoFocus
        />
      )}
    </>
  );
}
