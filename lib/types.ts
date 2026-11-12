// Types partagés (miroir du schéma supabase/schema.sql)

export type FrequencyUnit = "days" | "weeks" | "months" | "years";
export type RdvStatus = "planifie" | "valide" | "annule";

export interface Profile {
  id: string;
  email: string | null;
  display_name: string | null;
  timezone: string;
  notify_push: boolean;
  notify_email: boolean;
  daily_hour: number;
  due_lead_days: number;
  rdv_reminder_minutes: number;
  last_digest_date: string | null;
  created_at: string;
  updated_at: string;
}

export interface Contact {
  id: string;
  user_id: string;
  name: string;
  photo_path: string | null;
  category: string | null;
  phone: string | null;
  email: string | null;
  /** YYYY-MM-DD */
  birthday: string | null;
  notes: string | null;
  /** YYYY-MM-DD */
  last_meeting_date: string;
  frequency_value: number;
  frequency_unit: FrequencyUnit;
  /** YYYY-MM-DD — calculée en base (last_meeting_date + fréquence) */
  next_due_date: string;
  /** YYYY-MM-DD — report manuel de l'échéance */
  snooze_until: string | null;
  notified_current_cycle: boolean;
  created_at: string;
  updated_at: string;
}

export type ContactLite = Pick<Contact, "id" | "name" | "photo_path" | "category">;

export interface ContactInput {
  name: string;
  category?: string | null;
  phone?: string | null;
  email?: string | null;
  birthday?: string | null;
  notes?: string | null;
  last_meeting_date: string;
  frequency_value: number;
  frequency_unit: FrequencyUnit;
  photo_path?: string | null;
}

export interface Rendezvous {
  id: string;
  user_id: string;
  title: string | null;
  location: string | null;
  notes: string | null;
  /** ISO 8601 (timestamptz) */
  appointment_at: string;
  status: RdvStatus;
  reminder_sent: boolean;
  followup_sent: boolean;
  created_at: string;
  updated_at: string;
}

export interface Photo {
  id: string;
  user_id: string;
  contact_id: string | null;
  rendezvous_id: string | null;
  storage_path: string;
  caption: string | null;
  created_at: string;
}

export interface RendezvousWithContacts extends Rendezvous {
  contacts: ContactLite[];
  photos: Photo[];
}

export interface RdvInput {
  title?: string | null;
  location?: string | null;
  notes?: string | null;
  appointment_at: string;
  status?: RdvStatus;
}

export interface PushSubscriptionRow {
  id: string;
  user_id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  user_agent: string | null;
  created_at: string;
}

export interface NotificationRow {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string | null;
  url: string | null;
  channel: "push" | "email" | "none";
  created_at: string;
}

export const CATEGORY_SUGGESTIONS = ["Famille", "Amis", "Pro", "Autre"] as const;

export const FREQUENCY_PRESETS: { label: string; value: number; unit: FrequencyUnit }[] = [
  { label: "1 semaine", value: 1, unit: "weeks" },
  { label: "2 semaines", value: 2, unit: "weeks" },
  { label: "1 mois", value: 1, unit: "months" },
  { label: "2 mois", value: 2, unit: "months" },
  { label: "3 mois", value: 3, unit: "months" },
  { label: "6 mois", value: 6, unit: "months" },
  { label: "1 an", value: 1, unit: "years" },
];

export const RDV_STATUS_LABEL: Record<RdvStatus, string> = {
  planifie: "Planifié",
  valide: "A eu lieu",
  annule: "Annulé",
};
