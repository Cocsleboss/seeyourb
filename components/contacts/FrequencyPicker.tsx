"use client";

import { useState } from "react";
import { Chip, ChipRow, Input, Select } from "@/components/ui";
import { FREQUENCY_UNIT_LABEL } from "@/lib/dates";
import { FREQUENCY_PRESETS, type FrequencyUnit } from "@/lib/types";

const UNITS: FrequencyUnit[] = ["days", "weeks", "months", "years"];

export function isFrequencyPreset(value: number, unit: FrequencyUnit): boolean {
  return FREQUENCY_PRESETS.some((p) => p.value === value && p.unit === unit);
}

/** Choix de la fréquence de recontact : presets en chips + mode personnalisé (nombre + unité). */
export function FrequencyPicker({
  value,
  unit,
  onChange,
}: {
  value: number;
  unit: FrequencyUnit;
  onChange: (value: number, unit: FrequencyUnit) => void;
}) {
  const [custom, setCustom] = useState(() => !isFrequencyPreset(value, unit));
  return (
    <>
      <ChipRow>
        {FREQUENCY_PRESETS.map((p) => (
          <Chip
            key={p.label}
            active={!custom && value === p.value && unit === p.unit}
            onClick={() => {
              setCustom(false);
              onChange(p.value, p.unit);
            }}
          >
            {p.label}
          </Chip>
        ))}
        <Chip active={custom} onClick={() => setCustom(true)}>
          Personnalisée
        </Chip>
      </ChipRow>
      {custom && (
        <div className="mt-2 grid grid-cols-2 gap-2">
          <Input
            type="number"
            inputMode="numeric"
            min={1}
            max={1000}
            value={value}
            onChange={(e) => onChange(parseInt(e.target.value, 10) || 0, unit)}
            aria-label="Nombre"
          />
          <Select value={unit} onChange={(e) => onChange(value, e.target.value as FrequencyUnit)} aria-label="Unité">
            {UNITS.map((u) => (
              <option key={u} value={u}>
                {FREQUENCY_UNIT_LABEL[u][value > 1 ? 1 : 0]}
              </option>
            ))}
          </Select>
        </div>
      )}
    </>
  );
}
