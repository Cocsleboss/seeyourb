"use client";

import { useState } from "react";
import { Button } from "./Button";
import { Sheet } from "./Sheet";
import { useToast } from "./Toast";

export function ConfirmSheet({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = "Confirmer",
  cancelLabel = "Annuler",
  danger = false,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void> | void;
  title: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
}) {
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  return (
    <Sheet open={open} onClose={busy ? () => {} : onClose} title={title}>
      {message && <p className="text-[15px] text-gray-600 dark:text-gray-300">{message}</p>}
      <div className="mt-5 flex gap-3">
        <Button variant="secondary" full onClick={onClose} disabled={busy}>
          {cancelLabel}
        </Button>
        <Button
          variant={danger ? "danger" : "primary"}
          full
          loading={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await onConfirm();
              onClose();
            } catch (e) {
              toast.error(e instanceof Error ? e.message : "Action impossible");
            } finally {
              setBusy(false);
            }
          }}
        >
          {confirmLabel}
        </Button>
      </div>
    </Sheet>
  );
}
