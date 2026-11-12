"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { AuthShell } from "@/components/auth/AuthShell";
import { Button, Card, Field, Input, LinkButton, PageLoader, useToast } from "@/components/ui";
import { translateAuthError } from "@/lib/auth-errors";
import { createClient } from "@/lib/supabase/client";

export default function ResetPasswordPage() {
  const router = useRouter();
  const toast = useToast();
  const [ready, setReady] = useState<"loading" | "ok" | "none">("loading");
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    let done = false;
    supabase.auth.getSession().then(({ data }) => {
      if (!done) setReady(data.session ? "ok" : "none");
    });
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "PASSWORD_RECOVERY" || session) {
        done = true;
        setReady("ok");
      }
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (pw.length < 6) return setError("Le mot de passe doit contenir au moins 6 caractères.");
    if (pw !== pw2) return setError("Les deux mots de passe ne correspondent pas.");
    setBusy(true);
    try {
      const { error } = await createClient().auth.updateUser({ password: pw });
      if (error) throw error;
      toast.success("Mot de passe mis à jour");
      router.replace("/");
      router.refresh();
    } catch (err) {
      setError(translateAuthError(err instanceof Error ? err.message : String(err)));
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthShell title="Nouveau mot de passe" subtitle="Choisissez un nouveau mot de passe pour votre compte.">
      <Card>
        {ready === "loading" && <PageLoader label="Vérification du lien…" />}
        {ready === "none" && (
          <div className="space-y-4 text-center">
            <p className="font-semibold">Lien invalide ou expiré</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">
              Demandez un nouveau lien depuis « Mot de passe oublié » sur la page de connexion.
            </p>
            <LinkButton href="/login" full>
              Retour à la connexion
            </LinkButton>
          </div>
        )}
        {ready === "ok" && (
          <form onSubmit={submit} className="space-y-4" noValidate>
            <Field label="Nouveau mot de passe" htmlFor="pw" required hint="6 caractères minimum">
              <Input id="pw" type="password" autoComplete="new-password" minLength={6} value={pw} onChange={(e) => setPw(e.target.value)} required />
            </Field>
            <Field label="Confirmer le mot de passe" htmlFor="pw2" required>
              <Input id="pw2" type="password" autoComplete="new-password" minLength={6} value={pw2} onChange={(e) => setPw2(e.target.value)} required />
            </Field>
            {error && (
              <p role="alert" className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-200">
                {error}
              </p>
            )}
            <Button type="submit" full size="lg" loading={busy} disabled={pw.length < 6 || pw2.length < 6}>
              Enregistrer le mot de passe
            </Button>
          </form>
        )}
      </Card>
    </AuthShell>
  );
}
