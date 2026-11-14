// Types partagés (miroir du schéma supabase/schema.sql)

export type FrequencyUnit = "days" | "weeks" | "months" | "years";
export type RdvStatus = "planifie" | "valide" | "annule";

export interface Profile {
  id: string;
  email: string | null;
  display_name: string | null;
  /** nom d'utilisateur unique (sans le « @ ») ; null = pas encore choisi */
  username: string | null;
  /** YYYY-MM-DD — visible par les amis SeeU */
  birthday: string | null;
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
  /** ajouté à la main à la liste « à voir bientôt » (remis à false dès qu'on s'est vus) */
  see_soon: boolean;
  /** compte SeeU de cette personne, si c'est un ami associé */
  linked_user_id: string | null;
  created_at: string;
  updated_at: string;
}

export type ContactLite = Pick<Contact, "id" | "name" | "photo_path" | "category" | "linked_user_id">;

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
  linked_user_id?: string | null;
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
  /** commun aux copies d'un rendez-vous partagé entre amis (null = non partagé) */
  share_id: string | null;
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

/* ---------------------------- Amis & partage ---------------------------- */

/** Une ligne de list_friends() : un ami accepté ou une demande en cours. */
export interface Friend {
  friendship_id: string;
  user_id: string;
  username: string | null;
  display_name: string;
  /** renseigné uniquement pour les amis acceptés */
  email: string | null;
  status: "pending" | "accepted";
  /** true = demande reçue (à moi de répondre), false = demande que j'ai envoyée */
  incoming: boolean;
  created_at: string;
}

export type FriendRequestStatus = "sent" | "accepted" | "already_sent" | "already_friends" | "self" | "not_found";

export interface FriendRequestResult {
  status: FriendRequestStatus;
  friendship_id?: string;
  user_id?: string;
  display_name?: string;
  username?: string;
}

/** Résultat de search_users() : un compte trouvé par son nom d'utilisateur. */
export interface UserSearchResult {
  user_id: string;
  username: string;
  display_name: string;
  relation: "none" | "friends" | "sent" | "received";
}

export type InviteStatus = "pending" | "accepted" | "declined";

/** Invitation envoyée ou reçue pour un rendez-vous (table rdv_invitations). */
export interface RdvInvitation {
  id: string;
  rdv_id: string;
  from_user: string;
  to_user: string;
  status: InviteStatus;
  to_rdv_id: string | null;
  created_at: string;
  responded_at: string | null;
}

/** Invitation reçue en attente, avec le détail du rendez-vous proposé (list_rdv_invites()). */
export interface IncomingInvite {
  id: string;
  rdv_id: string;
  from_user: string;
  from_name: string;
  title: string | null;
  location: string | null;
  appointment_at: string;
  rdv_status: RdvStatus;
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
