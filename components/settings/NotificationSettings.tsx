"use client";

import { Bell, BellOff, Share, Smartphone, SquarePlus } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { Button, Card, Field, Row, RowList, Select, Toggle, useToast } from "@/components/ui";
import { listNotifications, updateProfile } from "@/lib/data";
import { formatDateTime } from "@/lib/dates";
import { useAsyncData } from "@/lib/hooks";
import { getPushState, subscribeToPush, unsubscribeFromPush, type PushState } from "@/lib/push-client";
import { useSession } from "@/lib/session";
import type { Profile } from "@/lib/types";

const HOURS = Array.from({ length: 24 }, (_, h) => h);
const LEAD_OPTIONS = [
  { value: 0, label: "Le jour de l'échéance" },
  { value: 1, label: "1 jour avant" },
  { value: 3, label: "3 jours avant" },
  { value: 7, label: "1 semaine avant" },
  { value: 14, label: "2 semaines avant" },
];
const RDV_OPTIONS = [
  { value: 15, label: "15 minutes avant" },
  { value: 30, label: "30 minutes avant" },
  { value: 60, label: "1 heure avant" },
  { value: 120, label: "2 heures avant" },
  { value: 1440, label: "La veille (24 h avant)" },
];

interface Health {
  push: boolean;
  email: "brevo" | "resend" | null;
  cron: boolean;
  serviceRole: boolean;
  appUrl: string | null;
}

const KIND_LABEL: Record<string, string> = {
  due_digest: "Contacts à recontacter",
  rdv_reminder: "Rappel de rendez-vous",
  rdv_followup: "Suivi de rendez-vous",
  birthday: "Anniversaire",
  test: "Test",
};

export function NotificationSettings() {
  const { user, profile, setProfile } = useSession();
  const toast = useToast();
  const [pushState, setPushState] = useState<PushState | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [healthOpen, setHealthOpen] = useState(false);
  const { data: notifications, reload: reloadNotifications } = useAsyncData(() => listNotifications(10), []);

  const refreshState = useCallback(() => getPushState().then(setPushState), []);
  useEffect(() => {
    refreshState();
  }, [refreshState]);

  useEffect(() => {
    if (!healthOpen || health) return;
    fetch("/api/health")
      .then((r) => (r.ok ? r.json() : null))
      .then((h) => setHealth(h))
      .catch(() => setHealth(null));
  }, [healthOpen, health]);

  const save = async (patch: Partial<Profile>) => {
    if (!profile) return;
    const prev = profile;
    setProfile({ ...profile, ...patch });
    try {
      const p = await updateProfile(patch);
      setProfile(p);
    } catch (e) {
      setProfile(prev);
      toast.error(e instanceof Error ? e.message : "Enregistrement impossible");
    }
  };

  const enable = async () => {
    setBusy("enable");
    const res = await subscribeToPush();
    setBusy(null);
    if (res.ok) toast.success("Notifications activées sur cet appareil");
    else if (res.reason === "denied") toast.error("Permission refusée : autorisez les notifications dans les réglages de l'appareil.");
    else toast.error(res.message || "Activation impossible");
    refreshState();
  };

  const disable = async () => {
    setBusy("disable");
    await unsubscribeFromPush();
    setBusy(null);
    toast.info("Notifications désactivées sur cet appareil");
    refreshState();
  };

  const test = async () => {
    setBusy("test");
    try {
      const res = await fetch("/api/push/test", { method: "POST" });
      const data = (await res.json()) as { channel?: string; pushSent?: number; detail?: string; error?: string };
      if (!res.ok) throw new Error(data.error || "Erreur serveur");
      if (data.channel === "push") toast.success(`Notification push envoyée (${data.pushSent} appareil${(data.pushSent ?? 0) > 1 ? "s" : ""})`);
      else if (data.channel === "email") toast.success(`Email envoyé à ${user.email}`);
      else toast.error(`Aucun canal disponible : ${data.detail || "activez le push ou configurez l'email"}`);
      reloadNotifications();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Envoi impossible");
    } finally {
      setBusy(null);
    }
  };

  const pushStatus = (() => {
    switch (pushState) {
      case "subscribed":
        return {
          icon: <Bell className="h-5 w-5 text-emerald-600" />,
          text: "Activées sur cet appareil",
          action: (
            <Button size="sm" variant="outline" loading={busy === "disable"} onClick={disable}>
              Désactiver
            </Button>
          ),
        };
      case "not-subscribed":
        return {
          icon: <BellOff className="h-5 w-5 text-gray-400" />,
          text: "Non activées sur cet appareil",
          action: (
            <Button size="sm" loading={busy === "enable"} onClick={enable}>
              Activer
            </Button>
          ),
        };
      case "needs-install":
        return {
          icon: <Smartphone className="h-5 w-5 text-brand-600" />,
          text: (
            <span>
              Sur iPhone, installez d&apos;abord l&apos;app : <Share className="inline h-4 w-4 text-brand-600" /> Partager →{" "}
              <SquarePlus className="inline h-4 w-4 text-brand-600" /> Sur l&apos;écran d&apos;accueil, puis ouvrez-la depuis l&apos;icône.
            </span>
          ),
        };
      case "denied":
        return { icon: <BellOff className="h-5 w-5 text-red-500" />, text: "Notifications bloquées : autorisez-les dans Réglages → Notifications → SeeYourB." };
      case "unsupported":
        return { icon: <BellOff className="h-5 w-5 text-gray-400" />, text: "Ce navigateur ne supporte pas les notifications push ; les rappels partiront par email." };
      case "no-key":
        return { icon: <BellOff className="h-5 w-5 text-amber-500" />, text: "Push non configuré sur le serveur (clé VAPID manquante, voir README)." };
      default:
        return { icon: <Bell className="h-5 w-5 text-gray-300" />, text: "Vérification…" };
    }
  })();

  return (
    <div className="space-y-3">
      <Card className="p-0">
        <RowList>
          <Row>
            <div className="shrink-0">{pushStatus.icon}</div>
            <div className="min-w-0 flex-1 text-sm">
              <p className="font-medium text-gray-900 dark:text-gray-100">Notifications push</p>
              <p className="text-gray-500 dark:text-gray-400">{pushStatus.text}</p>
            </div>
            {pushStatus.action}
          </Row>
          <Row>
            <div className="min-w-0 flex-1 text-sm">
              <p className="font-medium text-gray-900 dark:text-gray-100">Rappels push</p>
              <p className="text-gray-500 dark:text-gray-400">Sur tous les appareils où vous les avez activées</p>
            </div>
            <Toggle checked={profile?.notify_push ?? true} onChange={(v) => save({ notify_push: v })} label="Rappels push" disabled={!profile} />
          </Row>
          <Row>
            <div className="min-w-0 flex-1 text-sm">
              <p className="font-medium text-gray-900 dark:text-gray-100">Rappels par email</p>
              <p className="text-gray-500 dark:text-gray-400">Utilisés si aucun appareil n&apos;a les notifications push activées</p>
            </div>
            <Toggle checked={profile?.notify_email ?? true} onChange={(v) => save({ notify_email: v })} label="Rappels par email" disabled={!profile} />
          </Row>
        </RowList>
      </Card>

      <Card className="space-y-4">
        <Field label="Heure du rappel quotidien" htmlFor="daily-hour" hint="Un seul récapitulatif par jour des contacts à recontacter">
          <Select id="daily-hour" value={profile?.daily_hour ?? 8} onChange={(e) => save({ daily_hour: Number(e.target.value) })} disabled={!profile}>
            {HOURS.map((h) => (
              <option key={h} value={h}>
                {h}h00
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Prévenir" htmlFor="lead">
          <Select id="lead" value={profile?.due_lead_days ?? 0} onChange={(e) => save({ due_lead_days: Number(e.target.value) })} disabled={!profile}>
            {LEAD_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Rappel avant un rendez-vous" htmlFor="rdv-lead">
          <Select id="rdv-lead" value={profile?.rdv_reminder_minutes ?? 30} onChange={(e) => save({ rdv_reminder_minutes: Number(e.target.value) })} disabled={!profile}>
            {RDV_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </Select>
        </Field>
        <Button variant="secondary" full loading={busy === "test"} onClick={test}>
          <Bell className="h-5 w-5" /> Envoyer une notification de test
        </Button>
      </Card>

      <Card className="p-0">
        <button
          type="button"
          onClick={() => setHealthOpen((v) => !v)}
          className="flex w-full items-center justify-between px-4 py-3 text-left text-sm font-medium text-gray-900 dark:text-gray-100"
          aria-expanded={healthOpen}
        >
          Diagnostic de configuration
          <span className="text-gray-400">{healthOpen ? "−" : "+"}</span>
        </button>
        {healthOpen && (
          <div className="border-t border-gray-100 px-4 py-3 text-sm dark:border-gray-800">
            {!health ? (
              <p className="text-gray-500">Chargement…</p>
            ) : (
              <ul className="space-y-1.5">
                <HealthLine ok={health.push} label="Push (clés VAPID)" hint="npm run vapid → variables NEXT_PUBLIC_VAPID_PUBLIC_KEY / VAPID_PRIVATE_KEY" />
                <HealthLine ok={Boolean(health.email)} label={`Email${health.email ? ` (${health.email})` : ""}`} hint="BREVO_API_KEY ou RESEND_API_KEY + EMAIL_FROM" />
                <HealthLine ok={health.cron} label="Cron (CRON_SECRET)" hint="définir CRON_SECRET puis exécuter supabase/cron.sql" />
                <HealthLine ok={health.serviceRole} label="Clé service role" hint="SUPABASE_SERVICE_ROLE_KEY" />
                <HealthLine ok={Boolean(health.appUrl)} label={`URL de l'app${health.appUrl ? ` : ${health.appUrl}` : ""}`} hint="NEXT_PUBLIC_APP_URL (liens dans les emails)" />
              </ul>
            )}
          </div>
        )}
      </Card>

      <div>
        <p className="mb-2 text-sm font-semibold text-gray-900 dark:text-gray-100">Dernières notifications</p>
        <Card className="p-0">
          {!notifications?.length ? (
            <p className="px-4 py-4 text-sm text-gray-500">Aucune notification envoyée pour l&apos;instant.</p>
          ) : (
            <RowList>
              {notifications.map((n) => (
                <Row key={n.id} className="items-start">
                  <div className="min-w-0 flex-1 text-sm">
                    <p className="truncate font-medium text-gray-900 dark:text-gray-100">{n.title}</p>
                    {n.body && <p className="line-clamp-2 text-gray-500 dark:text-gray-400">{n.body}</p>}
                    <p className="mt-0.5 text-xs text-gray-400">
                      {KIND_LABEL[n.kind] ?? n.kind} · {formatDateTime(n.created_at)}
                    </p>
                  </div>
                  <span
                    className={`shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                      n.channel === "push"
                        ? "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200"
                        : n.channel === "email"
                          ? "bg-sky-100 text-sky-800 dark:bg-sky-900/40 dark:text-sky-200"
                          : "bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-300"
                    }`}
                  >
                    {n.channel === "none" ? "aucune" : n.channel}
                  </span>
                </Row>
              ))}
            </RowList>
          )}
        </Card>
      </div>
    </div>
  );
}

function HealthLine({ ok, label, hint }: { ok: boolean; label: string; hint: string }) {
  return (
    <li className="flex items-start gap-2">
      <span className={ok ? "text-emerald-600" : "text-red-500"}>{ok ? "✓" : "✗"}</span>
      <span className="min-w-0">
        <span className="text-gray-900 dark:text-gray-100">{label}</span>
        {!ok && <span className="block text-xs text-gray-500">{hint}</span>}
      </span>
    </li>
  );
}
