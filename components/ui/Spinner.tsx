import { Loader2 } from "lucide-react";

export function Spinner({ className = "h-5 w-5" }: { className?: string }) {
  return <Loader2 className={`animate-spin text-brand-600 ${className}`} aria-label="Chargement" />;
}

export function PageLoader({ label = "Chargement…" }: { label?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16 text-sm text-gray-500">
      <Spinner className="h-7 w-7" />
      <span>{label}</span>
    </div>
  );
}
