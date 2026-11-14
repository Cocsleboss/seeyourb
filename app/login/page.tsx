"use client";

import { Eye, EyeOff, MailCheck } from "lucide-react";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState, type FormEvent } from "react";
import { AuthShell } from "@/components/auth/AuthShell";
import { UsernameInput, usernameOk, type UsernameState } from "@/components/UsernameInput";
import { Button, Card, Field, Input, PageLoader, SegmentedControl } from "@/components/ui";
import { translateAuthError } from "@/lib/auth-errors";
import { createClient, supabaseConfigured } from "@/lib/supabase/client";

type Mode = "login" | "signup" | "magic" | "forgot";

function safeNext(raw: string | null): string {
  return raw && raw.startsWith("/") && !raw.startsWith("//") ? raw : "/";
}

const SUBMIT_LABEL: Record<Mode, string> = {
  login: "Se connecter",
  signup: "Créer mon compte",
  magic: "Recevoir le lien",
  forgot: "Envoyer le lien",
};

function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));

  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [usernameState, setUsernameState] = useState<UsernameState>("empty");
  const [showPw, setShowPw] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(params.get("error"));
  const [sent, setSent] = useState<{ title: string; text: string } | null>(null);

  const switchTo = (m: Mode) => {
    setMode(m);
    setError(null);
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const supabase = createClient();
    const origin = window.location.origin;
    const cleanEmail = email.trim().toLowerCase();
    try {
      if (mode === "login") {
        const { error } = await supabase.auth.signInWithPassword({ email: cleanEmail, password });
        if (error) throw error;
        router.replace(next);
        router.refresh();
      } else if (mode === "signup") {
        const { data, error } = await supabase.auth.signUp({
          email: cleanEmail,
          password,
          options: {
            emailRedirectTo: `${origin}/auth/callback?next=/`,
            data: { username, ...(name.trim() ? { display_name: name.trim() } : {}) },
          },
        });
        if (error) throw error;
        if (data.session) {
          router.replace(next);
          router.refresh();
        } else if (data.user && Array.isArray(data.user.identities) && data.user.identities.length === 0) {
          setError("Un compte existe déjà avec cet email. Connectez-vous ou utilisez « Mot de passe oublié ».");
        } else {
          setSent({
            title: "Vérifiez votre boîte mail",
            text: `Un lien de confirmation a été envoyé à ${cleanEmail}. Ouvrez-le pour activer votre compte (pensez aux spams).`,
          });
        }
      } else if (mode === "magic") {
        const { error } = await supabase.auth.signInWithOtp({
          email: cleanEmail,
          options: { emailRedirectTo: `${origin}/auth/callback?next=/`, shouldCreateUser: true },
        });
        if (error) throw error;
        setSent({ title: "Lien envoyé", text: `Ouvrez le lien reçu à ${cleanEmail} pour vous connecter (pensez aux spams).` });
      } else {
        const { error } = await supabase.auth.resetPasswordForEmail(cleanEmail, {
          redirectTo: `${origin}/auth/callback?next=/auth/reset-password`,
        });
        if (error) throw error;
        setSent({
          title: "Email envoyé",
          text: `Si un compte existe pour ${cleanEmail}, vous recevrez un lien pour choisir un nouveau mot de passe.`,
        });
      }
    } catch (err) {
      setError(translateAuthError(err instanceof Error ? err.message : String(err)));
    } finally {
      setBusy(false);
    }
  };

  if (!supabaseConfigured()) {
    return (
      <AuthShell>
        <Card className="space-y-2">
          <h2 className="font-semibold text-red-600">Configuration manquante</h2>
          <p className="text-sm text-gray-600 dark:text-gray-300">
            Les variables <code className="rounded bg-gray-100 px-1 dark:bg-gray-800">NEXT_PUBLIC_SUPABASE_URL</code> et{" "}
            <code className="rounded bg-gray-100 px-1 dark:bg-gray-800">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> ne sont pas
            définies. Ajoutez-les (fichier .env.local en local, ou Settings → Environment Variables sur Vercel) puis
            redéployez. Voir le README.
          </p>
        </Card>
      </AuthShell>
    );
  }

  if (sent) {
    return (
      <AuthShell>
        <Card className="flex flex-col items-center text-center">
          <div className="mb-3 flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-300">
            <MailCheck className="h-7 w-7" />
          </div>
          <h2 className="text-lg font-semibold">{sent.title}</h2>
          <p className="mt-1 text-sm text-gray-600 dark:text-gray-300">{sent.text}</p>
          <Button
            variant="secondary"
            full
            className="mt-5"
            onClick={() => {
              setSent(null);
              switchTo("login");
            }}
          >
            Retour
          </Button>
        </Card>
      </AuthShell>
    );
  }

  const isPwMode = mode === "login" || mode === "signup";

  return (
    <AuthShell>
      <Card className="space-y-4">
        {isPwMode ? (
          <SegmentedControl<Mode>
            options={[
              { value: "login", label: "Connexion" },
              { value: "signup", label: "Inscription" },
            ]}
            value={mode}
            onChange={switchTo}
          />
        ) : (
          <div>
            <h2 className="text-lg font-semibold">{mode === "magic" ? "Lien magique" : "Mot de passe oublié"}</h2>
            <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
              {mode === "magic"
                ? "Recevez un lien de connexion par email, sans mot de passe."
                : "Indiquez votre email : vous recevrez un lien pour choisir un nouveau mot de passe."}
            </p>
          </div>
        )}

        <form onSubmit={submit} className="space-y-4" noValidate>
          {mode === "signup" && (
            <>
              <Field label="Prénom (nom affiché)" htmlFor="name">
                <Input id="name" autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex. Andrea" maxLength={60} />
              </Field>
              <UsernameInput value={username} onChange={setUsername} onState={setUsernameState} required />
            </>
          )}
          <Field label="Email" htmlFor="email" required>
            <Input
              id="email"
              type="email"
              inputMode="email"
              autoCapitalize="none"
              autoCorrect="off"
              autoComplete="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="vous@exemple.com"
            />
          </Field>
          {isPwMode && (
            <Field label="Mot de passe" htmlFor="password" required hint={mode === "signup" ? "6 caractères minimum" : undefined}>
              <div className="relative">
                <Input
                  id="password"
                  type={showPw ? "text" : "password"}
                  minLength={6}
                  required
                  autoComplete={mode === "signup" ? "new-password" : "current-password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="pr-12"
                />
                <button
                  type="button"
                  onClick={() => setShowPw((v) => !v)}
                  aria-label={showPw ? "Masquer le mot de passe" : "Afficher le mot de passe"}
                  className="absolute right-1 top-1/2 flex h-9 w-9 -translate-y-1/2 items-center justify-center rounded-lg text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800"
                >
                  {showPw ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                </button>
              </div>
            </Field>
          )}

          {error && (
            <p role="alert" className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-200">
              {error}
            </p>
          )}

          <Button type="submit" full size="lg" loading={busy} disabled={!email || (isPwMode && password.length < 6) || (mode === "signup" && !usernameOk(usernameState))}>
            {SUBMIT_LABEL[mode]}
          </Button>
        </form>

        <div className="flex flex-col items-center gap-2 text-sm text-brand-600 dark:text-brand-300">
          {mode === "login" && (
            <>
              <button type="button" className="hover:underline" onClick={() => switchTo("forgot")}>
                Mot de passe oublié ?
              </button>
              <button type="button" className="hover:underline" onClick={() => switchTo("magic")}>
                Recevoir un lien magique par email
              </button>
            </>
          )}
          {mode === "signup" && (
            <button type="button" className="hover:underline" onClick={() => switchTo("magic")}>
              S&apos;inscrire avec un lien magique (sans mot de passe)
            </button>
          )}
          {(mode === "magic" || mode === "forgot") && (
            <button type="button" className="hover:underline" onClick={() => switchTo("login")}>
              Retour à la connexion
            </button>
          )}
        </div>
      </Card>
    </AuthShell>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={<PageLoader />}>
      <LoginForm />
    </Suspense>
  );
}
