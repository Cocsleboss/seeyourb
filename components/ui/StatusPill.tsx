import { RDV_STATUS_LABEL, type RdvStatus } from "@/lib/types";

const STYLES: Record<RdvStatus, string> = {
  planifie: "bg-brand-100 text-brand-800 dark:bg-brand-900/40 dark:text-brand-200",
  valide: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200",
  annule: "bg-gray-200 text-gray-700 dark:bg-gray-800 dark:text-gray-300",
};

export function StatusPill({ status, className = "" }: { status: RdvStatus; className?: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${STYLES[status]} ${className}`}>
      {RDV_STATUS_LABEL[status]}
    </span>
  );
}
