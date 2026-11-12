import Link from "next/link";

export default function NotFound() {
  return (
    <main className="flex min-h-dvh flex-col items-center justify-center px-6 text-center">
      <p className="text-6xl font-black text-brand-600">404</p>
      <h1 className="mt-2 text-xl font-bold">Page introuvable</h1>
      <p className="mt-1 text-sm text-gray-500">Cette page n&apos;existe pas ou a été supprimée.</p>
      <Link href="/" className="mt-6 inline-flex h-11 items-center rounded-xl bg-brand-600 px-5 font-semibold text-white">
        Retour à l&apos;accueil
      </Link>
    </main>
  );
}
