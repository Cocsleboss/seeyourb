"use client";

import { LogOut } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState, type FormEvent, type ReactNode } from "react";
import { AuthShell } from "@/components/auth/AuthShell";
import { UsernameInput, usernameOk, type UsernameState } from "@/components/UsernameInput";
import { Button, Card, Field, Input } from "@/components/ui";
import { signOut, updateProfile } from "@/lib/data";
import { todayISO } from "@/lib/dates";
import { useSession } from "@/lib/session";
import { suggestUsername } from "@/lib/username";

/**
 * Bloque l'app tant que le profil est incomplet (pas de nom d'utilisateur) :
 * comptes créés avant la v1.2, ou inscription par lien magique.
 * `username === undefined` = base pas encore migrée → on laisse passer.
 */
export function ProfileGate({ children }: { children: ReactNode }) {
  const { profile } = useSession();
  if (profile && profile.username === null) return <CompleteProfile />;
  return <>{children}</>;
}

function CompleteProfile() {
  const { user, profile, setProfile } = useSession();
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [state, setState] = useState<UsernameState>("empty");
  const [name, setName] = useState("");
  const [birthday, setBirthday] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // pré-remplissage à partir de ce qu'on connaît déjà
  useEffect(() => {
    const known = profile?.display_name?.trim() ?? "";
    const fromEmail = user.email?.split("@")[0] ?? "";
    setName(known && known !== fromEmail ? known : "");
    const suggestion = suggestUsername(known || fromEmail);
    setUsername(suggestion.length >= 3 ? suggestion : "");
    setBirthday(profile?.birthday ?? "");
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const p = await updateProfile({ username, display_name: name.trim() || username, birthday: birthday || null });
      setProfile(p);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Enregistrement impossible");
    } finally {
      setBusy(false);
    }
  };

  const logout = async () => {
    await signOut().catch(() => {});
    router.replace("/login");
    router.refresh();
  };

  return (
    <AuthShell title="Complétez votre profil" subtitle="SeeU permet maintenant d'ajouter des amis : choisissez le nom d'utilisateur avec lequel ils vous trouveront.">
      <Card>
        <form onSubmit={submit} className="space-y-4" noValidate>
          <UsernameInput value={username} onChange={setUsername} onState={setState} required autoFocus />
          <Field label="Prénom ou nom affiché" htmlFor="gate-name" required hint="C'est ce que vos amis verront à côté de votre @.">
            <Input id="gate-name" autoComplete="name" value={name} onChange={(e) => setName(e.target.value)} placeholder="Ex. Andrea" maxLength={60} />
          </Field>
          <Field label="Date de naissance (facultatif)" htmlFor="gate-birthday" hint="Visible par vos amis SeeU uniquement, pour qu'ils pensent à votre anniversaire.">
            <Input id="gate-birthday" type="date" value={birthday} max={todayISO()} onChange={(e) => setBirthday(e.target.value)} />
          </Field>
          {error && (
            <p role="alert" className="rounded-xl bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-200">
              {error}
            </p>
          )}
          <Button type="submit" full size="lg" loading={busy} disabled={!usernameOk(state) || !name.trim()}>
            Continuer
          </Button>
        </form>
      </Card>
      <p className="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
        Connecté avec {user.email}.{" "}
        <button type="button" onClick={logout} className="inline-flex items-center gap-1 font-medium text-brand-600 hover:underline dark:text-brand-300">
          <LogOut className="h-3.5 w-3.5" /> Se déconnecter
        </button>
      </p>
    </AuthShell>
  );
}
