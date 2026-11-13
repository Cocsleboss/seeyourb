"use client";

import { BookUser, Download } from "lucide-react";
import { useEffect, useState } from "react";
import { AccountSection } from "@/components/settings/AccountSection";
import { InstallHelp } from "@/components/settings/InstallHelp";
import { NotificationSettings } from "@/components/settings/NotificationSettings";
import { Button, Card, Field, Input, LinkButton, Page, SectionTitle, TopBar, buttonClasses, useToast } from "@/components/ui";
import { updateProfile } from "@/lib/data";
import { useSession } from "@/lib/session";

export default function SettingsPage() {
  const { user, profile, setProfile } = useSession();
  const toast = useToast();
  const [name, setName] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (profile) setName(profile.display_name ?? "");
  }, [profile]);

  const dirty = profile ? name.trim() !== (profile.display_name ?? "") : false;

  const saveName = async () => {
    setSaving(true);
    try {
      const p = await updateProfile({ display_name: name.trim() || null });
      setProfile(p);
      toast.success("Profil mis à jour");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Enregistrement impossible");
    } finally {
      setSaving(false);
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
              <div className="flex gap-2">
                <Input id="display-name" value={name} onChange={(e) => setName(e.target.value)} placeholder="Votre prénom" maxLength={60} disabled={!profile} />
                <Button onClick={saveName} disabled={!dirty} loading={saving}>
                  Enregistrer
                </Button>
              </div>
            </Field>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
              <dt className="text-gray-500 dark:text-gray-400">Email</dt>
              <dd className="break-all text-gray-900 dark:text-gray-100">{user.email}</dd>
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
              <span className="font-medium">1.0.0</span>
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

        <p className="pb-4 text-center text-xs text-gray-400">SeeYourB · Vos données restent privées et ne sont jamais partagées.</p>
      </Page>
    </>
  );
}
