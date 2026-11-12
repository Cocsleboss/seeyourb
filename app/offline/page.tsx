import { WifiOff } from "lucide-react";

export const metadata = { title: "Hors ligne" };

export default function OfflinePage() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center px-6 text-center">
      <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-gray-100 text-gray-500 dark:bg-gray-800">
        <WifiOff className="h-8 w-8" />
      </div>
      <h1 className="text-xl font-bold">Vous êtes hors ligne</h1>
      <p className="mt-2 max-w-xs text-sm text-gray-500">
        SeeYourB a besoin d&apos;une connexion pour charger vos contacts et rendez-vous. Réessayez dès que le réseau
        revient.
      </p>
      <a
        href="/"
        className="mt-6 inline-flex h-11 items-center rounded-xl bg-brand-600 px-5 font-semibold text-white"
      >
        Réessayer
      </a>
    </main>
  );
}
