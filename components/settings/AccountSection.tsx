"use client";

import { KeyRound, LogOut, Trash2 } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { Button, Card, ConfirmSheet, Field, Input, Sheet, useToast } from "@/components/ui";
import { translateAuthError } from "@/lib/auth-errors";
import { signOut } from "@/lib/data";
import { createClient } from "@/lib/supabase/client";

export function AccountSection() {
  const router = useRouter();
  const toast = useToast();
  const [pwOpen, setPwOpen] = useState(false);
  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [pwBusy, setPwBusy] = useState(false);
  const [pwError, setPwError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [logoutBusy, setLogoutBusy] = useState(false);

  const changePassword = async (e: FormEvent) => {
    e.preventDefault();
    setPwError(null);
    if (pw.length < 6) return setPwError("Le mot de passe doit contenir au moins 6 caractères.");
    if (pw !== pw2) return setPwError("Les deux mots de passe ne correspondent pas.");
    setPwBusy(true);
    try {
      const { error } = await createClient().auth.updateUser({ password: pw });
      if (error) throw error;
      toast.success("Mot de passe mis à jour");
      setPwOpen(false);
      setPw("");
      setPw2("");
    } catch (err) {
      setPwError(translateAuthError(err instanceof Error ? err.message : String(err)));
    } finally {
      setPwBusy(false);
    }
  };

  const logout = async () => {
    setLogoutBusy(true);
    try {
      await signOut();
    } finally {
      router.replace("/login");
      router.refresh();
    }
  };

  const deleteAccount = async () => {
    const res = await fetch("/api/account/delete", { method: "POST" });
    const data = (await res.json().catch(() => ({}))) as { ok?: boolean; error?: string };
    if (!res.ok || !data.ok) {
      toast.error(data.error || "Suppression impossible");
      return;
    }
    await signOut().catch(() => {});
    router.replace("/login");
    router.refresh();
  };

  return (
    <>
      <Card className="space-y-2">
        <Button variant="outline" full onClick={() => setPwOpen(true)}>
          <KeyRound className="h-5 w-5" /> Changer le mot de passe
        </Button>
        <Button variant="secondary" full loading={logoutBusy} onClick={logout}>
          <LogOut className="h-5 w-5" /> Se déconnecter
        </Button>
        <Button variant="danger" full onClick={() => setConfirmDelete(true)}>
          <Trash2 className="h-5 w-5" /> Supprimer mon compte
        </Button>
      </Card>

      <Sheet open={pwOpen} onClose={() => !pwBusy && setPwOpen(false)} title="Changer le mot de passe">
        <form onSubmit={changePassword} className="space-y-4" noValidate>
          <Field label="Nouveau mot de passe" htmlFor="new-pw" required hint="6 caractères minimum">
            <Input id="new-pw" type="password" autoComplete="new-password" minLength={6} value={pw} onChange={(e) => setPw(e.target.value)} required />
          </Field>
          <Field label="Confirmer" htmlFor="new-pw2" required>
            <Input id="new-pw2" type="password" autoComplete="new-password" minLength={6} value={pw2} onChange={(e) => setPw2(e.target.value)} required />
          </Field>
          {pwError && <p className="text-sm text-red-600">{pwError}</p>}
          <Button type="submit" full size="lg" loading={pwBusy} disabled={pw.length < 6 || pw2.length < 6}>
            Enregistrer
          </Button>
        </form>
      </Sheet>

      <ConfirmSheet
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        danger
        title="Supprimer définitivement votre compte ?"
        message="Tous vos contacts, rendez-vous et photos seront effacés. Cette action est irréversible."
        confirmLabel="Supprimer mon compte"
        onConfirm={deleteAccount}
      />
    </>
  );
}
