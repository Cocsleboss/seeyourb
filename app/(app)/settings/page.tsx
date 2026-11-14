"use client";

import { BookUser, Download, Share2 } from "lucide-react";
import { useEffect, useState } from "react";
import { AccountSection } from "@/components/settings/AccountSection";
import { InstallHelp } from "@/components/settings/InstallHelp";
import { NotificationSettings } from "@/components/settings/NotificationSettings";
import { UsernameInput, usernameOk, type UsernameState } from "@/components/UsernameInput";
import { Button, Card, Field, Input, LinkButton, Page, SectionTitle, TopBar, buttonClasses, useToast } from "@/components/ui";
import { updateProfile } from "@/lib/data";
import { todayISO } from "@/lib/dates";
import { useSession } from "@/lib/session";
import { handle } from "@/lib/username";

export default function SettingsPage() {
  const { user, profile, setProfile } = useSession();
  const toast = useToast();
  const [name, setName] = useState("");
  const [username, setUsername] = useState("");
  const [usernameState, setUsernameState] = useState<UsernameState>("empty");
  const [birthday, setBirthday] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!profile) return;
    setName(profile.display_name ?? "");
    setUsername(profile.username ?? "");
    setBirthday(profile.birthday ?? "");
  }, [profile]);

  /** false tant que la base n'a pas été migrée (colonne username absente) */
  const hasUsername = profile ? profile.username !== undefined : false;
  const dirty = profile
    ? name.trim() !== (profile.display_name ?? "") ||
      (hasUsername && (username !== (profile.username ?? "") || birthday !== (profile.birthday ?? "")))
    : false;
  const valid = name.trim().length > 0 && (!hasUsername || usernameOk(usernameState));

  const saveProfile = async () => {
    setSaving(true);
    try {
      const p = await updateProfile({
        display_name: name.trim(),
        ...(hasUsername ? { username, birthday: birthday || null } : {}),
      });
      setProfile(p);
      toast.success("Profil mis à jour");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Enregistrement impossible");
    } finally {
      setSaving(false);
    }
  };

  const shareProfile = async () => {
    if (!profile?.username) return;
    const url = `${window.location.origin}/friends?add=${encodeURIComponent(profile.username)}`;
    const text = `Ajoute-moi sur SeeU : ${handle(profile.username)}`;
    try {
      if (navigator.share) await navigator.share({ title: "SeeU", text, url });
      else {
        await navigator.clipboard.writeText(`${text} ${url}`);
        toast.success("Lien copié");
      }
    } catch {
      /* partage annulé */
    }
  };

  return (
    <>
      <TopBar title="Réglages" />
      <Page className="space-y-6">
        <section>
          <SectionTitle>Profil</SectionTitle>
          <Card className="space-y-4">
            <Field label="Nom affiché" htmlFor="display-name">
              <Input id="display-name" value={name} onChange={(e) => setName(e.target.value)} placeholder="Votre prénom" maxLength={60} disabled={!profile} />
            </Field>
            {hasUsername && (
              <>
                <UsernameInput value={username} onChange={setUsername} onState={setUsernameState} current={profile?.username} />
                <Field label="Date de naissance" htmlFor="my-birthday" hint="Visible par vos amis SeeU uniquement : leur fiche à votre nom se remplit toute seule.">
                  <Input id="my-birthday" type="date" value={birthday} max={todayISO()} onChange={(e) => setBirthday(e.target.value)} />
                </Field>
              </>
            )}
            <div className="flex gap-2">
              <Button className="flex-1" onClick={saveProfile} disabled={!dirty || !valid} loading={saving}>
                Enregistrer
              </Button>
              {profile?.username && (
                <Button variant="secondary" onClick={shareProfile}>
                  <Share2 className="h-5 w-5" /> Partager mon @
                </Button>
              )}
            </div>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
              <dt className="text-gray-500 dark:text-gray-400">Email</dt>
              <dd className="break-all text-gray-900 dark:text-gray-100">
                {user.email}
                <span className="block text-xs text-gray-500">Jamais affiché aux autres utilisateurs avant qu&apos;ils soient vos amis</span>
              </dd>
              <dt className="text-gray-500 dark:text-gray-400">Fuseau horaire</dt>
              <dd className="text-gray-900 dark:text-gray-100">
                {profile?.timezone ?? "…"}
                <span className="block text-xs text-gray-500">Détecté automatiquement, utilisé pour l&apos;heure des rappels</span>
              </dd>
            </dl>
          </Card>
        </section>

        <section>
          <SectionTitle>Notifications</SectionTitle>
          <NotificationSettings />
        </section>

        <section>
          <SectionTitle>Application</SectionTitle>
          <div className="space-y-3">
            <InstallHelp />
            <Card className="flex items-center justify-between text-sm">
              <span className="text-gray-500 dark:text-gray-400">Version</span>
              <span className="font-medium">1.2.0</span>
            </Card>
          </div>
        </section>

        <section>
          <SectionTitle>Données</SectionTitle>
          <Card className="space-y-2">
            <LinkButton href="/contacts/import" variant="outline" full>
              <BookUser className="h-5 w-5" /> Importer des contacts du téléphone
            </LinkButton>
            <p className="text-xs text-gray-500 dark:text-gray-400">Depuis le carnet d&apos;adresses ou un fichier .vcf, avec revue contact par contact.</p>
            <a href="/api/export" download className={buttonClasses({ variant: "outline", full: true })}>
              <Download className="h-5 w-5" /> Exporter mes données (JSON)
            </a>
            <p className="text-xs text-gray-500 dark:text-gray-400">Contacts, rendez-vous et métadonnées des photos.</p>
          </Card>
        </section>

        <section>
          <SectionTitle>Compte</SectionTitle>
          <AccountSection />
        </section>

        <p className="pb-4 text-center text-xs text-gray-400">SeeU · Vos données restent privées : seuls les rendez-vous que vous envoyez à un ami sont partagés avec lui.</p>
      </Page>
    </>
  );
}
