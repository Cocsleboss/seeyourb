/**
 * Couche d'accès aux données côté navigateur.
 * Toutes les requêtes passent par la RLS de Supabase : l'utilisateur ne voit que ses données.
 * Les fonctions lèvent une Error (message en français) en cas d'échec → à attraper dans l'UI (toast).
 */
import { createClient } from "@/lib/supabase/client";
import { removeFiles, uploadImage } from "@/lib/photos";
import type {
  Contact,
  ContactInput,
  ContactLite,
  Friend,
  FriendRequestResult,
  IncomingInvite,
  NotificationRow,
  Photo,
  Profile,
  RdvInput,
  RdvInvitation,
  RdvStatus,
  Rendezvous,
  RendezvousWithContacts,
  UserSearchResult,
} from "@/lib/types";

const sb = () => createClient();

function fail(error: { message: string } | null | undefined, fallback = "Une erreur est survenue"): never {
  const msg = error?.message || fallback;
  throw new Error(translateError(msg));
}

export function translateError(msg: string): string {
  const m = msg.toLowerCase();
  if (m.includes("failed to fetch") || m.includes("network")) return "Pas de connexion. Vérifiez votre réseau.";
  if (m.includes("jwt") || m.includes("not authenticated") || m.includes("refresh_token")) return "Session expirée, reconnectez-vous.";
  if (m.includes("row-level security")) return "Action non autorisée.";
  if (m.includes("idx_profiles_username")) return "Ce nom d'utilisateur est déjà pris.";
  if (m.includes("profiles_username_format")) return "Nom d'utilisateur invalide.";
  if (m.includes("duplicate key")) return "Cet élément existe déjà.";
  if (m.includes("could not find the function") || m.includes("schema cache") || (m.includes("column") && m.includes("does not exist")))
    return "Base de données pas encore à jour : lancez supabase/migration_v1.2.sql dans Supabase (SQL Editor).";
  if (m.includes("payload too large") || m.includes("exceeded the maximum allowed size")) return "Fichier trop volumineux (10 Mo max).";
  return msg;
}

export async function currentUserId(): Promise<string> {
  const {
    data: { session },
  } = await sb().auth.getSession();
  if (!session?.user) throw new Error("Session expirée, reconnectez-vous.");
  return session.user.id;
}

/* ------------------------------------------------------------------ */
/*  Profil                                                              */
/* ------------------------------------------------------------------ */

export function browserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "Europe/Paris";
  } catch {
    return "Europe/Paris";
  }
}

export async function getProfile(): Promise<Profile | null> {
  const { data, error } = await sb().from("profiles").select("*").maybeSingle();
  if (error) fail(error);
  return (data as Profile | null) ?? null;
}

/** Récupère le profil, le crée s'il manque, et synchronise le fuseau horaire du navigateur. */
export async function ensureProfile(user: { id: string; email: string | null }): Promise<Profile> {
  let profile = await getProfile();
  const tz = browserTimezone();
  if (!profile) {
    const { data, error } = await sb()
      .from("profiles")
      .upsert(
        {
          id: user.id,
          email: user.email,
          display_name: user.email ? user.email.split("@")[0] : null,
          timezone: tz,
        },
        { onConflict: "id" }
      )
      .select("*")
      .single();
    if (error) fail(error);
    profile = data as Profile;
  } else if (profile.timezone !== tz || (!profile.email && user.email)) {
    const { data } = await sb()
      .from("profiles")
      .update({ timezone: tz, email: profile.email ?? user.email })
      .eq("id", user.id)
      .select("*")
      .single();
    if (data) profile = data as Profile;
  }
  return profile;
}

export async function updateProfile(patch: Partial<Omit<Profile, "id" | "created_at" | "updated_at">>): Promise<Profile> {
  const uid = await currentUserId();
  const { data, error } = await sb().from("profiles").update(patch).eq("id", uid).select("*").single();
  if (error) fail(error);
  return data as Profile;
}

/** Vrai si ce nom d'utilisateur est valide et libre (ou déjà le mien). Utilisable avant connexion. */
export async function usernameAvailable(username: string): Promise<boolean> {
  const { data, error } = await sb().rpc("username_available", { p_username: username });
  if (error) fail(error);
  return data === true;
}

/* ------------------------------------------------------------------ */
/*  Contacts                                                            */
/* ------------------------------------------------------------------ */

export async function listContacts(): Promise<Contact[]> {
  const { data, error } = await sb().from("contacts").select("*").order("name", { ascending: true });
  if (error) fail(error);
  return (data ?? []) as Contact[];
}

export async function getContact(id: string): Promise<Contact | null> {
  const { data, error } = await sb().from("contacts").select("*").eq("id", id).maybeSingle();
  if (error) fail(error);
  return (data as Contact | null) ?? null;
}

function cleanContactInput(input: Partial<ContactInput>) {
  const out: Record<string, unknown> = { ...input };
  for (const k of ["category", "phone", "email", "birthday", "notes", "photo_path"] as const) {
    if (k in out) {
      const v = out[k];
      out[k] = typeof v === "string" && v.trim() === "" ? null : typeof v === "string" ? v.trim() : v;
    }
  }
  if (typeof out.name === "string") out.name = out.name.trim();
  return out;
}

export async function createContact(input: ContactInput): Promise<Contact> {
  const uid = await currentUserId();
  const { data, error } = await sb()
    .from("contacts")
    .insert({ ...cleanContactInput(input), user_id: uid })
    .select("*")
    .single();
  if (error) fail(error);
  return data as Contact;
}

/** Création groupée (import) : insère par lots de 100, renvoie les contacts créés. */
export async function createContacts(inputs: ContactInput[]): Promise<Contact[]> {
  const uid = await currentUserId();
  const created: Contact[] = [];
  for (let i = 0; i < inputs.length; i += 100) {
    const rows = inputs.slice(i, i + 100).map((input) => ({ ...cleanContactInput(input), user_id: uid }));
    const { data, error } = await sb().from("contacts").insert(rows).select("*");
    if (error) {
      const msg = translateError(error.message);
      throw new Error(created.length ? `${created.length} contact(s) ajouté(s) avant l'erreur : ${msg}` : msg);
    }
    created.push(...((data ?? []) as Contact[]));
  }
  return created;
}

export async function updateContact(
  id: string,
  patch: Partial<ContactInput> & { snooze_until?: string | null; see_soon?: boolean }
): Promise<Contact> {
  const { data, error } = await sb().from("contacts").update(cleanContactInput(patch)).eq("id", id).select("*").single();
  if (error) fail(error);
  return data as Contact;
}

/** Supprime le contact, sa photo de profil et les photos qui lui sont directement rattachées. */
export async function deleteContact(contact: Contact): Promise<void> {
  const { data: photos } = await sb().from("photos").select("storage_path").eq("contact_id", contact.id);
  const paths = [...((photos ?? []) as { storage_path: string }[]).map((p) => p.storage_path)];
  if (contact.photo_path) paths.push(contact.photo_path);
  const { error } = await sb().from("contacts").delete().eq("id", contact.id);
  if (error) fail(error);
  await removeFiles(paths).catch(() => {});
}

/** Remplace la photo de profil d'un contact (supprime l'ancienne). */
export async function setContactPhoto(contact: Contact, file: Blob | null): Promise<Contact> {
  const uid = await currentUserId();
  const newPath = file ? await uploadImage(file, uid) : null;
  const updated = await updateContact(contact.id, { photo_path: newPath });
  if (contact.photo_path && contact.photo_path !== newPath) await removeFiles([contact.photo_path]).catch(() => {});
  return updated;
}

/** Reporte l'échéance d'un contact à une date donnée (YYYY-MM-DD). */
export async function snoozeContact(id: string, untilISO: string): Promise<Contact> {
  return updateContact(id, { snooze_until: untilISO });
}

/** Ajoute / retire un contact de la liste « à voir bientôt », quelle que soit son échéance. */
export async function setSeeSoon(id: string, value: boolean): Promise<Contact> {
  return updateContact(id, { see_soon: value });
}

/**
 * "Vu aujourd'hui" : enregistre une rencontre déjà passée (rdv validé).
 * Le trigger en base met à jour la date de dernière rencontre → nouvelle échéance.
 */
export async function logMeeting(
  contactIds: string[],
  dateISO: string,
  opts: { time?: string; title?: string | null; notes?: string | null; location?: string | null } = {}
): Promise<RendezvousWithContacts> {
  const [y, m, d] = dateISO.split("-").map(Number);
  const [hh, mm] = (opts.time ?? "12:00").split(":").map(Number);
  const at = new Date(y, m - 1, d, hh || 12, mm || 0, 0, 0);
  return createRdv(
    { appointment_at: at.toISOString(), status: "valide", title: opts.title ?? null, notes: opts.notes ?? null, location: opts.location ?? null },
    contactIds
  );
}

/* ------------------------------------------------------------------ */
/*  Rendez-vous                                                         */
/* ------------------------------------------------------------------ */

const RDV_SELECT = "*, contact_rendezvous(contacts(id, name, photo_path, category, linked_user_id)), photos(*)";

type RawRdv = Rendezvous & {
  contact_rendezvous?: { contacts: ContactLite | null }[] | null;
  photos?: Photo[] | null;
};

function normalizeRdv(row: RawRdv): RendezvousWithContacts {
  const { contact_rendezvous, photos, ...rest } = row;
  const contacts = (contact_rendezvous ?? [])
    .map((x) => x.contacts)
    .filter((c): c is ContactLite => Boolean(c))
    .sort((a, b) => a.name.localeCompare(b.name, "fr"));
  const sortedPhotos = [...(photos ?? [])].sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
  return { ...(rest as Rendezvous), contacts, photos: sortedPhotos };
}

/** Tous les rendez-vous planifiés (passés non confirmés + à venir), du plus proche au plus lointain. */
export async function listPlannedRdv(): Promise<RendezvousWithContacts[]> {
  const { data, error } = await sb()
    .from("rendezvous")
    .select(RDV_SELECT)
    .eq("status", "planifie")
    .order("appointment_at", { ascending: true });
  if (error) fail(error);
  return ((data ?? []) as RawRdv[]).map(normalizeRdv);
}

/** Historique : rendez-vous validés ou annulés, du plus récent au plus ancien. */
export async function listHistory(limit = 200): Promise<RendezvousWithContacts[]> {
  const { data, error } = await sb()
    .from("rendezvous")
    .select(RDV_SELECT)
    .in("status", ["valide", "annule"])
    .order("appointment_at", { ascending: false })
    .limit(limit);
  if (error) fail(error);
  return ((data ?? []) as RawRdv[]).map(normalizeRdv);
}

/** Tous les rendez-vous (tous statuts) liés à un contact, du plus récent au plus ancien. */
export async function listRdvForContact(contactId: string): Promise<RendezvousWithContacts[]> {
  const { data: links, error: e1 } = await sb().from("contact_rendezvous").select("rendezvous_id").eq("contact_id", contactId);
  if (e1) fail(e1);
  const ids = ((links ?? []) as { rendezvous_id: string }[]).map((l) => l.rendezvous_id);
  if (!ids.length) return [];
  const { data, error } = await sb()
    .from("rendezvous")
    .select(RDV_SELECT)
    .in("id", ids)
    .order("appointment_at", { ascending: false });
  if (error) fail(error);
  return ((data ?? []) as RawRdv[]).map(normalizeRdv);
}

export async function getRdv(id: string): Promise<RendezvousWithContacts | null> {
  const { data, error } = await sb().from("rendezvous").select(RDV_SELECT).eq("id", id).maybeSingle();
  if (error) fail(error);
  return data ? normalizeRdv(data as RawRdv) : null;
}

function cleanRdvInput(input: Partial<RdvInput>) {
  const out: Record<string, unknown> = { ...input };
  for (const k of ["title", "location", "notes"] as const) {
    if (k in out) {
      const v = out[k];
      out[k] = typeof v === "string" && v.trim() === "" ? null : typeof v === "string" ? v.trim() : v;
    }
  }
  return out;
}

export async function createRdv(input: RdvInput, contactIds: string[]): Promise<RendezvousWithContacts> {
  const uid = await currentUserId();
  const { data, error } = await sb()
    .from("rendezvous")
    .insert({ ...cleanRdvInput(input), user_id: uid })
    .select("id")
    .single();
  if (error) fail(error);
  const id = (data as { id: string }).id;
  const unique = Array.from(new Set(contactIds));
  if (unique.length) {
    const { error: e2 } = await sb()
      .from("contact_rendezvous")
      .insert(unique.map((contact_id) => ({ contact_id, rendezvous_id: id, user_id: uid })));
    if (e2) {
      await sb().from("rendezvous").delete().eq("id", id);
      fail(e2);
    }
  }
  const rdv = await getRdv(id);
  if (!rdv) throw new Error("Rendez-vous introuvable après création");
  return rdv;
}

/** Met à jour un rendez-vous ; si contactIds est fourni, synchronise les participants. */
export async function updateRdv(id: string, patch: Partial<RdvInput>, contactIds?: string[]): Promise<RendezvousWithContacts> {
  const clean = cleanRdvInput(patch);
  if (Object.keys(clean).length) {
    // rendez-vous partagé : on regarde ce qui change pour prévenir les amis (validé, annulé, déplacé)
    type Before = Pick<Rendezvous, "share_id" | "status" | "appointment_at">;
    const before: Before | null =
      "status" in clean || "appointment_at" in clean
        ? (((await sb().from("rendezvous").select("share_id, status, appointment_at").eq("id", id).maybeSingle()).data as Before | null) ?? null)
        : null;
    const { error } = await sb().from("rendezvous").update(clean).eq("id", id);
    if (error) fail(error);
    if (before?.share_id) {
      const statusChanged = typeof clean.status === "string" && clean.status !== before.status;
      const moved =
        typeof clean.appointment_at === "string" && new Date(clean.appointment_at).getTime() !== new Date(before.appointment_at).getTime();
      if (statusChanged) notifySocial("rdv_change", id, clean.status as string);
      else if (moved) notifySocial("rdv_change", id, "moved");
    }
  }
  if (contactIds) {
    const uid = await currentUserId();
    const wanted = new Set(contactIds);
    const { data: links, error: e1 } = await sb().from("contact_rendezvous").select("contact_id").eq("rendezvous_id", id);
    if (e1) fail(e1);
    const existing = new Set(((links ?? []) as { contact_id: string }[]).map((l) => l.contact_id));
    const toRemove = Array.from(existing).filter((c) => !wanted.has(c));
    const toAdd = Array.from(wanted).filter((c) => !existing.has(c));
    if (toRemove.length) {
      const { error } = await sb().from("contact_rendezvous").delete().eq("rendezvous_id", id).in("contact_id", toRemove);
      if (error) fail(error);
    }
    if (toAdd.length) {
      const { error } = await sb()
        .from("contact_rendezvous")
        .insert(toAdd.map((contact_id) => ({ contact_id, rendezvous_id: id, user_id: uid })));
      if (error) fail(error);
    }
  }
  const rdv = await getRdv(id);
  if (!rdv) throw new Error("Rendez-vous introuvable");
  return rdv;
}

/** Change le statut : 'valide' met à jour automatiquement la date de dernière rencontre des contacts. */
export async function setRdvStatus(id: string, status: RdvStatus): Promise<RendezvousWithContacts> {
  return updateRdv(id, { status });
}

export async function deleteRdv(rdv: RendezvousWithContacts): Promise<void> {
  const paths = rdv.photos.map((p) => p.storage_path);
  const { error } = await sb().from("rendezvous").delete().eq("id", rdv.id);
  if (error) fail(error);
  await removeFiles(paths).catch(() => {});
}

/* ------------------------------------------------------------------ */
/*  Photos                                                              */
/* ------------------------------------------------------------------ */

/** Galerie d'un contact : photos rattachées au contact + photos de ses rendez-vous. */
export async function listPhotosForContact(contactId: string): Promise<Photo[]> {
  const { data: direct, error } = await sb().from("photos").select("*").eq("contact_id", contactId);
  if (error) fail(error);
  const { data: links } = await sb().from("contact_rendezvous").select("rendezvous_id").eq("contact_id", contactId);
  const ids = ((links ?? []) as { rendezvous_id: string }[]).map((l) => l.rendezvous_id);
  let viaRdv: Photo[] = [];
  if (ids.length) {
    const { data } = await sb().from("photos").select("*").in("rendezvous_id", ids);
    viaRdv = (data ?? []) as Photo[];
  }
  // + photos ajoutées par les amis sur les rendez-vous partagés avec ce contact
  let shared: Photo[] = [];
  if (ids.length) {
    const { data: sharedRdv } = await sb().from("rendezvous").select("id").in("id", ids).not("share_id", "is", null);
    const lists = await Promise.all(((sharedRdv ?? []) as { id: string }[]).map((r) => listSharedPhotosForRdv(r.id).catch(() => [])));
    shared = lists.flat();
  }
  const all = new Map<string, Photo>();
  [...((direct ?? []) as Photo[]), ...viaRdv, ...shared].forEach((p) => all.set(p.id, p));
  return Array.from(all.values()).sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
}

export async function listPhotosForRdv(rdvId: string): Promise<Photo[]> {
  const { data, error } = await sb().from("photos").select("*").eq("rendezvous_id", rdvId).order("created_at", { ascending: false });
  if (error) fail(error);
  return (data ?? []) as Photo[];
}

/** Photos ajoutées par les AUTRES participants d'un rendez-vous partagé (lecture seule). */
export async function listSharedPhotosForRdv(rdvId: string): Promise<Photo[]> {
  const { data, error } = await sb().rpc("list_shared_rdv_photos", { p_rdv: rdvId });
  if (error) fail(error);
  return (data ?? []) as Photo[];
}

export async function addPhoto(
  file: Blob,
  target: { contactId?: string | null; rdvId?: string | null; caption?: string | null }
): Promise<Photo> {
  if (!target.contactId && !target.rdvId) throw new Error("Cible de la photo manquante");
  const uid = await currentUserId();
  const path = await uploadImage(file, uid);
  const { data, error } = await sb()
    .from("photos")
    .insert({
      user_id: uid,
      contact_id: target.contactId ?? null,
      rendezvous_id: target.rdvId ?? null,
      storage_path: path,
      caption: target.caption ?? null,
    })
    .select("*")
    .single();
  if (error) {
    await removeFiles([path]).catch(() => {});
    fail(error);
  }
  return data as Photo;
}

export async function deletePhoto(photo: Photo): Promise<void> {
  const { error } = await sb().from("photos").delete().eq("id", photo.id);
  if (error) fail(error);
  await removeFiles([photo.storage_path]).catch(() => {});
}

/* ------------------------------------------------------------------ */
/*  Amis SeeU                                                           */
/* ------------------------------------------------------------------ */

/** Prévient l'autre personne (push / email). Jamais bloquant : un échec est ignoré. */
function notifySocial(
  type: "friend_request" | "friend_accept" | "rdv_invite" | "rdv_response" | "rdv_change" | "wave",
  id: string,
  change?: string
): void {
  fetch("/api/social/notify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ type, id, change }),
    keepalive: true,
  }).catch(() => {});
}

/** Amis acceptés + demandes en cours (reçues et envoyées). */
export async function listFriends(): Promise<Friend[]> {
  const { data, error } = await sb().rpc("list_friends");
  if (error) fail(error);
  return (data ?? []) as Friend[];
}

/** Comptes dont le nom d'utilisateur commence par la saisie (2 caractères minimum, 8 résultats). */
export async function searchUsers(query: string): Promise<UserSearchResult[]> {
  const { data, error } = await sb().rpc("search_users", { p_query: query });
  if (error) fail(error);
  return (data ?? []) as UserSearchResult[];
}

/** Envoie une demande d'ami au compte portant ce nom d'utilisateur (exact, avec ou sans « @ »). */
export async function sendFriendRequest(username: string): Promise<FriendRequestResult> {
  const { data, error } = await sb().rpc("send_friend_request", { p_username: username.trim() });
  if (error) fail(error);
  const res = data as FriendRequestResult;
  if (res.friendship_id && res.status === "sent") notifySocial("friend_request", res.friendship_id);
  if (res.friendship_id && res.status === "accepted") notifySocial("friend_accept", res.friendship_id);
  return res;
}

export async function respondFriendRequest(friendshipId: string, accept: boolean): Promise<void> {
  const { error } = await sb().rpc("respond_friend_request", { p_id: friendshipId, p_accept: accept });
  if (error) fail(error);
  if (accept) notifySocial("friend_accept", friendshipId);
}

/** Retire un ami ou annule une demande envoyée. Les contacts associés sont conservés (dissociés). */
export async function removeFriend(friendshipId: string): Promise<void> {
  const { error } = await sb().from("friendships").delete().eq("id", friendshipId);
  if (error) fail(error);
}

/** Associe un ami à l'un de mes contacts (un seul contact par ami). */
export async function linkFriendToContact(friendUserId: string, contactId: string): Promise<Contact> {
  const { error: e1 } = await sb().from("contacts").update({ linked_user_id: null }).eq("linked_user_id", friendUserId).neq("id", contactId);
  if (e1) fail(e1);
  const { data, error } = await sb().from("contacts").update({ linked_user_id: friendUserId }).eq("id", contactId).select("*").single();
  if (error) fail(error);
  return data as Contact;
}

/**
 * « Envie de te voir » : l'ami reçoit une notification et je passe dans sa liste « à voir bientôt ».
 * Limité à un signe par ami et par 24 h.
 */
export async function sendWave(friendUserId: string): Promise<void> {
  const { data, error } = await sb().rpc("send_wave", { p_to: friendUserId });
  if (error) fail(error);
  notifySocial("wave", data as string);
}

export async function unlinkFriend(friendUserId: string): Promise<void> {
  const { error } = await sb().from("contacts").update({ linked_user_id: null }).eq("linked_user_id", friendUserId);
  if (error) fail(error);
}

/* ------------------------------------------------------------------ */
/*  Rendez-vous partagés                                                */
/* ------------------------------------------------------------------ */

/** Propose un de mes rendez-vous à un ami. Renvoie l'id de l'invitation. */
export async function sendRdvInvite(rdvId: string, friendUserId: string): Promise<string> {
  const { data, error } = await sb().rpc("send_rdv_invite", { p_rdv: rdvId, p_to: friendUserId });
  if (error) fail(error);
  const id = data as string;
  notifySocial("rdv_invite", id);
  return id;
}

/** Invitations liées à un de mes rendez-vous (celles que j'ai envoyées, ou celle par laquelle je l'ai reçu). */
export async function listInvitesForRdv(rdvId: string): Promise<RdvInvitation[]> {
  const { data, error } = await sb().from("rdv_invitations").select("*").or(`rdv_id.eq.${rdvId},to_rdv_id.eq.${rdvId}`);
  if (error) fail(error);
  return (data ?? []) as RdvInvitation[];
}

export async function cancelRdvInvite(inviteId: string): Promise<void> {
  const { error } = await sb().from("rdv_invitations").delete().eq("id", inviteId);
  if (error) fail(error);
}

/** Invitations reçues, en attente de ma réponse. */
export async function listIncomingInvites(): Promise<IncomingInvite[]> {
  const { data, error } = await sb().rpc("list_rdv_invites");
  if (error) fail(error);
  return (data ?? []) as IncomingInvite[];
}

/** Accepte (→ renvoie l'id de MA copie du rendez-vous) ou refuse (→ null) une invitation. */
export async function respondRdvInvite(inviteId: string, accept: boolean): Promise<string | null> {
  const { data, error } = await sb().rpc("respond_rdv_invite", { p_invite: inviteId, p_accept: accept });
  if (error) fail(error);
  notifySocial("rdv_response", inviteId);
  return (data as string | null) ?? null;
}

/* ------------------------------------------------------------------ */
/*  Notifications (journal)                                             */
/* ------------------------------------------------------------------ */

export async function listNotifications(limit = 30): Promise<NotificationRow[]> {
  const { data, error } = await sb()
    .from("notifications")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) fail(error);
  return (data ?? []) as NotificationRow[];
}

/* ------------------------------------------------------------------ */
/*  Auth                                                                */
/* ------------------------------------------------------------------ */

export async function signOut(): Promise<void> {
  await sb().auth.signOut();
}
