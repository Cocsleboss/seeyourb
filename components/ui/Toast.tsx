"use client";

import { AlertCircle, CheckCircle2, Info } from "lucide-react";
import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from "react";

type ToastType = "success" | "error" | "info";
interface ToastItem {
  id: number;
  type: ToastType;
  message: string;
}

interface ToastApi {
  show: (type: ToastType, message: string) => void;
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const counter = useRef(0);

  const show = useCallback((type: ToastType, message: string) => {
    const id = ++counter.current;
    setItems((prev) => [...prev.slice(-2), { id, type, message }]);
    window.setTimeout(() => setItems((prev) => prev.filter((t) => t.id !== id)), type === "error" ? 5000 : 3200);
  }, []);

  const api = useMemo<ToastApi>(
    () => ({
      show,
      success: (m) => show("success", m),
      error: (m) => show("error", m),
      info: (m) => show("info", m),
    }),
    [show]
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 top-0 z-[60] flex flex-col items-center gap-2 px-4 pt-[max(0.75rem,env(safe-area-inset-top))]">
        {items.map((t) => (
          <div
            key={t.id}
            role="status"
            className={`pointer-events-auto flex w-full max-w-md animate-fade-in items-center gap-2.5 rounded-2xl px-4 py-3 text-sm font-medium shadow-lg ${
              t.type === "success"
                ? "bg-emerald-600 text-white"
                : t.type === "error"
                  ? "bg-red-600 text-white"
                  : "bg-gray-900 text-white dark:bg-gray-100 dark:text-gray-900"
            }`}
          >
            {t.type === "success" ? (
              <CheckCircle2 className="h-5 w-5 shrink-0" />
            ) : t.type === "error" ? (
              <AlertCircle className="h-5 w-5 shrink-0" />
            ) : (
              <Info className="h-5 w-5 shrink-0" />
            )}
            <span className="flex-1">{t.message}</span>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast doit être utilisé dans <ToastProvider>");
  return ctx;
}
