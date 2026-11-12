"use client";

import { Camera } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { buttonClasses, type ButtonVariant } from "@/components/ui/Button";

/** Bouton qui ouvre le sélecteur de photos (galerie ou appareil photo sur mobile). */
export function PhotoPicker({
  onPick,
  multiple = false,
  children,
  variant = "secondary",
  className = "",
  disabled,
}: {
  onPick: (files: File[]) => void;
  multiple?: boolean;
  children?: ReactNode;
  variant?: ButtonVariant;
  className?: string;
  disabled?: boolean;
}) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <input
        ref={ref}
        type="file"
        accept="image/*"
        multiple={multiple}
        className="hidden"
        onChange={(e) => {
          const files = Array.from(e.target.files ?? []);
          e.target.value = "";
          if (files.length) onPick(files);
        }}
      />
      <button
        type="button"
        disabled={disabled}
        onClick={() => ref.current?.click()}
        className={buttonClasses({ variant, className })}
      >
        <Camera className="h-5 w-5" />
        {children ?? (multiple ? "Ajouter des photos" : "Ajouter une photo")}
      </button>
    </>
  );
}
