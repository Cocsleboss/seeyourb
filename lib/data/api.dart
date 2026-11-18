// Data access. Every query goes through Supabase RLS: a user only sees their rows.
// Methods throw; UI catches and shows errorMessage(e) in a toast.
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../core/images.dart';
import '../core/i18n.dart';
import '../domain/dates.dart';
import '../domain/models.dart';

const _rdvSelect = '*, contact_rendezvous(contacts(id, name, photo_path, categories, linked_user_id)), photos(*), '
    'events(id, organizer_id, visibility, slots_open, description, member_count, going_count, guests_can_invite, link, lat, lng)';

/// Hides invitations I declined (rsvp null = my own rendezvous).
const _notDeclined = 'rsvp.is.null,rsvp.in.(pending,accepted)';
const photosBucket = 'photos';
const avatarsBucket = 'avatars';

String _randomId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class Api {
  Api(this.sb);
  final SupabaseClient sb;

  String get uid {
    final id = sb.auth.currentUser?.id;
    if (id == null) throw AppException(tr.errSessionExpired);
    return id;
  }

  /* ------------------------------ Profile ------------------------------ */

  Future<Profile?> getProfile() async {
    final row = await sb.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Gets the profile (creates it if missing) and syncs the device timezone.
  /// Loads (or creates) my profile and keeps its time zone and language up to date
  /// (notifications are written in the profile's language).
  Future<Profile> ensureProfile(String timezone, String locale) async {
    final user = sb.auth.currentUser!;
    var profile = await getProfile();
    if (profile == null) {
      final row = await sb
          .from('profiles')
          .upsert({'id': user.id, 'email': user.email, 'display_name': user.email?.split('@').first, 'timezone': timezone, 'locale': locale})
          .select()
          .single();
      return Profile.fromJson(row);
    }
    if (profile.timezone != timezone || profile.locale != locale || (profile.email == null && user.email != null)) {
      final row = await sb
          .from('profiles')
          .update({'timezone': timezone, 'locale': locale, 'email': profile.email ?? user.email})
          .eq('id', user.id)
          .select()
          .single();
      profile = Profile.fromJson(row);
    }
    return profile;
  }

  /// SeeU profile picture: public bucket (anyone who sees me in SeeU), random file name.
  Future<Profile> setMyAvatar(Uint8List? bytes, {String? oldPath}) async {
    String? path;
    if (bytes != null) {
      path = '$uid/${_randomId()}.jpg';
      final jpg = await compressImage(bytes, shortSide: avatarShortSide);
      await sb.storage.from(avatarsBucket).uploadBinary(path, jpg, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    }
    final p = await updateProfile({'avatar_path': path});
    if (oldPath != null && oldPath != path) {
      try {
        await sb.storage.from(avatarsBucket).remove([oldPath]);
      } catch (_) {}
    }
    return p;
  }

  String avatarUrl(String path) => sb.storage.from(avatarsBucket).getPublicUrl(path);

  /// Profile pictures of SeeU users (only those who have one).
  Future<Map<String, String>> profileAvatars(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await sb.rpc('profile_avatars', params: {'p_ids': ids}) as List;
    return {
      for (final r in rows.cast<Map<String, dynamic>>()) r['user_id'] as String: avatarUrl(r['avatar_path'] as String),
    };
  }

  Future<Profile> updateProfile(Map<String, dynamic> patch) async {
    final row = await sb.from('profiles').update(patch).eq('id', uid).select().single();
    return Profile.fromJson(row);
  }

  /// True if the username is valid and free (or already mine). Works signed-out.
  Future<bool> usernameAvailable(String username) async {
    final res = await sb.rpc('username_available', params: {'p_username': username});
    return res == true;
  }

  /// Another user's page (or mine) as I may see it; null = not found / not visible.
  Future<UserProfile?> getUserProfile(String username) async {
    final res = await sb.rpc('get_user_profile', params: {'p_username': username});
    return res == null ? null : UserProfile.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// What the public web page shows for this username (null: disabled / unknown).
  Future<Map<String, dynamic>?> getPublicProfile(String username) async {
    final res = await sb.rpc('get_public_profile', params: {'p_username': username});
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }

  /// Activity for the statistics: a new session after 30 min without activity,
  /// otherwise the current one is extended. Never blocks the user.
  Future<void> touchSession(String platform, String version) =>
      sb.rpc('touch_session', params: {'p_platform': platform, 'p_version': version});

  /* ------------------------------ Contacts ----------------------------- */

  Future<List<Contact>> listContacts() async {
    final rows = await sb.from('contacts').select().order('name');
    return rows.map(Contact.fromJson).toList();
  }

  Future<Contact> createContact(ContactInput input) async {
    final row = await sb.from('contacts').insert({...input.toJson(), 'user_id': uid}).select().single();
    return Contact.fromJson(row);
  }

  /// Bulk create (import), by batches of 100.
  Future<int> createContacts(List<ContactInput> inputs) async {
    var created = 0;
    for (var i = 0; i < inputs.length; i += 100) {
      final batch = inputs.sublist(i, min(i + 100, inputs.length)).map((c) => {...c.toJson(), 'user_id': uid}).toList();
      try {
        await sb.from('contacts').insert(batch);
        created += batch.length;
      } catch (e) {
        if (created > 0) throw AppException(tr.errContactsAddedBeforeError(created, errorMessage(e)));
        rethrow;
      }
    }
    return created;
  }

  Future<Contact> updateContact(String id, Map<String, dynamic> patch) async {
    final row = await sb.from('contacts').update(patch).eq('id', id).select().single();
    return Contact.fromJson(row);
  }

  /// Deletes the contact, its profile photo and the photos attached to it
  /// (its rendezvous links and photos cascade in the database).
  Future<void> deleteContact(Contact contact) async {
    final photos = await sb.from('photos').select('storage_path, thumb_path').eq('contact_id', contact.id);
    final rdvLinks = await sb.from('contact_rendezvous').select('rendezvous_id').eq('contact_id', contact.id);
    final rdvIds = rdvLinks.map((l) => l['rendezvous_id'] as String).toList();
    final paths = [...photos.expand(_photoPaths), ?contact.photoPath];
    // Rendezvous whose only participant is this contact go away with it.
    if (rdvIds.isNotEmpty) {
      final others = await sb.from('contact_rendezvous').select('rendezvous_id').inFilter('rendezvous_id', rdvIds).neq('contact_id', contact.id);
      final shared = others.map((o) => o['rendezvous_id'] as String).toSet();
      final orphan = rdvIds.where((id) => !shared.contains(id)).toList();
      if (orphan.isNotEmpty) {
        final rdvPhotos = await sb.from('photos').select('storage_path, thumb_path').inFilter('rendezvous_id', orphan);
        paths.addAll(rdvPhotos.expand(_photoPaths));
        await sb.from('rendezvous').delete().inFilter('id', orphan);
      }
    }
    await sb.from('contacts').delete().eq('id', contact.id);
    await _removeFiles(paths);
  }

  Future<Contact> setContactPhoto(Contact contact, Uint8List? bytes) async {
    final newPath = bytes == null ? null : await uploadImage(await compressImage(bytes, shortSide: avatarShortSide));
    final updated = await updateContact(contact.id, {'photo_path': newPath});
    if (contact.photoPath != null && contact.photoPath != newPath) await _removeFiles([contact.photoPath!]);
    return updated;
  }

  Future<Contact> snoozeContact(String id, DateTime until) => updateContact(id, {'snooze_until': dayIso(until)});

  Future<Contact> setSeeSoon(String id, bool value) => updateContact(id, {'see_soon': value});

  /// "Vu" : records a meeting that already happened (validated rendezvous).
  /// The database trigger then moves the contacts' last meeting date.
  Future<Rendezvous> logMeeting(List<String> contactIds, DateTime day, {String? notes}) {
    final at = DateTime(day.year, day.month, day.day, 12);
    return createRdv(RdvInput(appointmentAt: at, status: RdvStatus.valide, notes: notes), contactIds);
  }

  /* ----------------------------- Rendezvous ---------------------------- */

  Future<List<Rendezvous>> listPlannedRdv() async {
    final rows = await sb.from('rendezvous').select(_rdvSelect).eq('status', 'planifie').or(_notDeclined).order('appointment_at');
    return rows.map(Rendezvous.fromJson).toList();
  }

  Future<List<Rendezvous>> listHistory({int limit = 200}) async {
    final rows = await sb
        .from('rendezvous')
        .select(_rdvSelect)
        .inFilter('status', ['valide', 'annule'])
        .or(_notDeclined)
        .order('appointment_at', ascending: false)
        .limit(limit);
    return rows.map(Rendezvous.fromJson).toList();
  }

  /// Validated or cancelled rendezvous between two days (history calendar).
  Future<List<Rendezvous>> listHistoryBetween(DateTime from, DateTime to) async {
    final rows = await sb
        .from('rendezvous')
        .select(_rdvSelect)
        .inFilter('status', ['valide', 'annule'])
        .or(_notDeclined)
        .gte('appointment_at', from.toUtc().toIso8601String())
        .lt('appointment_at', to.toUtc().toIso8601String())
        .order('appointment_at');
    return rows.map(Rendezvous.fromJson).toList();
  }

  Future<List<Rendezvous>> listRdvForContact(String contactId) async {
    final links = await sb.from('contact_rendezvous').select('rendezvous_id').eq('contact_id', contactId);
    final ids = links.map((l) => l['rendezvous_id'] as String).toList();
    if (ids.isEmpty) return [];
    final rows = await sb.from('rendezvous').select(_rdvSelect).inFilter('id', ids).order('appointment_at', ascending: false);
    return rows.map(Rendezvous.fromJson).toList();
  }

  Future<Rendezvous?> getRdv(String id) async {
    final row = await sb.from('rendezvous').select(_rdvSelect).eq('id', id).maybeSingle();
    return row == null ? null : Rendezvous.fromJson(row);
  }

  Future<Rendezvous> createRdv(RdvInput input, List<String> contactIds) async {
    final row = await sb.from('rendezvous').insert({...input.toJson(), 'user_id': uid}).select('id').single();
    final id = row['id'] as String;
    final unique = contactIds.toSet();
    if (unique.isNotEmpty) {
      try {
        await sb
            .from('contact_rendezvous')
            .insert(unique.map((c) => {'contact_id': c, 'rendezvous_id': id, 'user_id': uid}).toList());
      } catch (e) {
        await sb.from('rendezvous').delete().eq('id', id);
        rethrow;
      }
    }
    return (await getRdv(id))!;
  }

  /// Updates fields; if [contactIds] is given, syncs the participants.
  Future<Rendezvous> updateRdv(String id, Map<String, dynamic> patch, {List<String>? contactIds}) async {
    if (patch.isNotEmpty) await sb.from('rendezvous').update(patch).eq('id', id);
    if (contactIds != null) {
      final links = await sb.from('contact_rendezvous').select('contact_id').eq('rendezvous_id', id);
      final existing = links.map((l) => l['contact_id'] as String).toSet();
      final wanted = contactIds.toSet();
      final toRemove = existing.difference(wanted).toList();
      final toAdd = wanted.difference(existing).toList();
      if (toRemove.isNotEmpty) {
        await sb.from('contact_rendezvous').delete().eq('rendezvous_id', id).inFilter('contact_id', toRemove);
      }
      if (toAdd.isNotEmpty) {
        await sb.from('contact_rendezvous').insert(toAdd.map((c) => {'contact_id': c, 'rendezvous_id': id, 'user_id': uid}).toList());
      }
    }
    final rdv = await getRdv(id);
    if (rdv == null) throw AppException(tr.errRdvNotFound);
    return rdv;
  }

  Future<Rendezvous> setRdvStatus(String id, RdvStatus status) => updateRdv(id, {'status': status.name});

  /* ------------------------------- Events ------------------------------ */

  /// Creates or edits an event (+ my copy, contacts, timeslots, invitations). Returns my copy's id.
  Future<String> saveEvent(EventInput input) async => await sb.rpc('save_event', params: {'p': input.toJson()}) as String;

  /// Join / answer an event seen in a feed. Returns my copy's id (null when declining without one).
  Future<String?> joinEvent(String eventId, Rsvp answer) async =>
      await sb.rpc('join_event', params: {'p_event': eventId, 'p_status': answer.name}) as String?;

  // ---- Invitation links ----
  /// My link for this event (created if needed); [renew]: a new one, the old stops working.
  Future<String> createEventLink(String eventId, {bool renew = false}) async =>
      await sb.rpc('create_event_link', params: {'p_event': eventId, 'p_new': renew}) as String;

  /// My active link, if any (doesn't create one).
  Future<String?> myEventLink(String eventId) async => await sb.rpc('get_my_event_link', params: {'p_event': eventId}) as String?;

  /// Disables my link ([all]: every link of the event; organizer only).
  Future<void> revokeEventLink(String eventId, {bool all = false}) =>
      sb.rpc('revoke_event_link', params: {'p_event': eventId, 'p_all': all});

  Future<LinkedEvent?> eventByLink(String token) async {
    final res = await sb.rpc('get_event_by_link', params: {'p_token': token});
    return res == null ? null : LinkedEvent.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Joins through a link ([answer]: accepted or pending). Returns my copy's id.
  Future<String> joinByLink(String token, Rsvp answer) async =>
      await sb.rpc('join_event_by_link', params: {'p_token': token, 'p_status': answer.name}) as String;

  /// Organizer: removes someone from the event (they can't come back by a link).
  Future<void> removeEventMember(String eventId, String userId) =>
      sb.rpc('remove_event_member', params: {'p_event': eventId, 'p_user': userId});

  Future<bool> canCreatePublicEvents() async => (await sb.rpc('can_create_public_events')) as bool? ?? false;

  /// scope: 'contacts' (friends' events) or 'public'.
  Future<List<FeedEvent>> listFeed(String scope, {String? query, FeedEvent? after, int limit = 30}) async {
    final rows = await sb.rpc('list_feed_events', params: {
      'p_scope': scope,
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'p_limit': limit,
      'p_after_at': after?.appointmentAt.toUtc().toIso8601String(),
      'p_after_id': after?.id,
    }) as List;
    return rows.map((r) => FeedEvent.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<FeedEvent?> getEvent(String eventId) async {
    final rows = await sb.rpc('get_event', params: {'p_event': eventId}) as List;
    return rows.isEmpty ? null : FeedEvent.fromJson(rows.first as Map<String, dynamic>);
  }

  Future<List<Participant>> listParticipants(String eventId) async {
    final rows = await sb.rpc('list_event_participants', params: {'p_event': eventId}) as List;
    return rows.map((r) => Participant.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Other members' contacts without a SeeU account. Empty when the server
  /// function isn't deployed yet (my own ones come from my copy anyway).
  Future<List<EventGuest>> listGuests(String eventId) async {
    try {
      final rows = await sb.rpc('list_event_guests', params: {'p_event': eventId}) as List;
      return rows.map((r) => EventGuest.fromJson(r as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') return const [];
      rethrow;
    }
  }

  Future<List<EventSlot>> listSlots(String eventId) async {
    final rows = await sb.rpc('list_event_slots', params: {'p_event': eventId}) as List;
    return rows.map((r) => EventSlot.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> voteSlot(String slotId, SlotAnswer? answer) =>
      sb.rpc('vote_slot', params: {'p_slot': slotId, 'p_answer': answer?.name});

  /// Sends my answers for all timeslots (unanswered = maybe). Returns my resulting RSVP
  /// (null for the organizer): ≥ 1 yes → going, all no → declined, otherwise maybe.
  Future<Rsvp?> submitAvailability(String eventId, Map<String, SlotAnswer> answers) async {
    final res = await sb.rpc('submit_availability', params: {
      'p_event': eventId,
      'p_votes': [for (final e in answers.entries) {'slot': e.key, 'answer': e.value.name}],
    });
    return Rsvp.parse(res as String?);
  }

  Future<void> chooseSlot(String slotId) => sb.rpc('choose_event_slot', params: {'p_slot': slotId});

  /// My public event shown (or not) on my public profile ("Choisis" mode).
  Future<void> setShowOnProfile(String rdvId, bool show) =>
      sb.from('rendezvous').update({'show_on_profile': show}).eq('id', rdvId);

  /// Friends and contacts living near a place far from my home ("you could see…").
  /// Empty when the server function isn't deployed yet.
  Future<List<NearbyPerson>> peopleNear(double lat, double lng, {String? eventId}) async {
    try {
      final rows = await sb.rpc('people_near', params: {'p_lat': lat, 'p_lng': lng, 'p_event': eventId}) as List;
      return rows.map((r) => NearbyPerson.fromJson(r as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.code == '42883') return const [];
      rethrow;
    }
  }

  /* -------------------------------- Chat ------------------------------- */

  /// Latest messages first.
  Future<List<ChatMessage>> listMessages(String eventId, {DateTime? before, int limit = 50}) async {
    final rows = await sb.rpc('list_event_messages', params: {
      'p_event': eventId,
      'p_before': before?.toUtc().toIso8601String(),
      'p_limit': limit,
    }) as List;
    return rows.map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> sendMessage(String eventId, String body) =>
      sb.from('event_messages').insert({'event_id': eventId, 'user_id': uid, 'body': body.trim()});

  Future<void> deleteMessage(String id) => sb.from('event_messages').delete().eq('id', id);

  Future<void> markChatRead(String rdvId) =>
      sb.from('rendezvous').update({'chat_read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', rdvId);

  /// New messages of an event, live (Supabase Realtime). Call the returned function to stop.
  void Function() watchMessages(String eventId, void Function(Map<String, dynamic> row) onInsert, void Function(String id) onDelete) {
    final channel = sb
        .channel('event-chat:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: eventId),
          callback: (p) => onInsert(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'event_messages',
          callback: (p) {
            final id = p.oldRecord['id'];
            if (id is String) onDelete(id);
          },
        )
        .subscribe();
    return () => channel.unsubscribe();
  }

  /* ---------------------------- Mute & block --------------------------- */

  Future<void> muteUser(String userId) =>
      sb.from('user_mutes').upsert({'user_id': uid, 'target_user': userId}, onConflict: 'user_id,target_user', ignoreDuplicates: true);
  Future<void> unmuteUser(String userId) => sb.from('user_mutes').delete().eq('user_id', uid).eq('target_user', userId);
  Future<void> muteEvent(String eventId) =>
      sb.from('user_mutes').upsert({'user_id': uid, 'event_id': eventId}, onConflict: 'user_id,event_id', ignoreDuplicates: true);
  Future<void> unmuteEvent(String eventId) => sb.from('user_mutes').delete().eq('user_id', uid).eq('event_id', eventId);
  Future<void> deleteMute(String id) => sb.from('user_mutes').delete().eq('id', id);

  Future<List<MuteEntry>> listMutes() async {
    final rows = await sb.rpc('list_mutes') as List;
    return rows.map((r) => MuteEntry.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> blockUser(String userId) => sb.rpc('block_user', params: {'p_user': userId});

  /// Reports a person, or something of theirs (the most specific target wins:
  /// message, photo, event). Anonymous for the reported person.
  Future<void> report(ReportReason reason,
          {String? comment, String? userId, String? eventId, String? photoId, String? messageId}) =>
      sb.rpc('report_content', params: {
        'p_reason': reason.value,
        'p_comment': (comment == null || comment.trim().isEmpty) ? null : comment.trim(),
        'p_user': userId,
        'p_event': eventId,
        'p_photo': photoId,
        'p_message': messageId,
      });
  Future<void> unblockUser(String userId) => sb.rpc('unblock_user', params: {'p_user': userId});

  Future<List<BlockedUser>> listBlocked() async {
    final rows = await sb.rpc('list_blocked_users') as List;
    return rows.map((r) => BlockedUser.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Deletes my copy. The organizer of a shared event that is still planned cancels it
  /// for everyone first (otherwise it would keep running without anyone to manage it).
  /// My private notes on my copy of an event.
  Future<void> setRdvNotes(String rdvId, String notes) =>
      sb.from('rendezvous').update({'notes': notes.trim().isEmpty ? null : notes.trim()}).eq('id', rdvId);

  /// Adds some of my contacts to my copy of an event (the friends among them
  /// are then invited by the caller).
  Future<void> addContactsToRdv(String rdvId, List<String> contactIds) async {
    if (contactIds.isEmpty) return;
    await sb.from('contact_rendezvous').upsert(
        [for (final c in contactIds.toSet()) {'contact_id': c, 'rendezvous_id': rdvId, 'user_id': uid}],
        onConflict: 'contact_id,rendezvous_id', ignoreDuplicates: true);
  }

  Future<void> deleteRdv(Rendezvous rdv) async {
    if (rdv.isOrganizer && rdv.isShared && rdv.status == RdvStatus.planifie) {
      await sb.from('rendezvous').update({'status': RdvStatus.annule.name}).eq('id', rdv.id);
    }
    await sb.from('rendezvous').delete().eq('id', rdv.id);
    await _removeFiles(rdv.photos.expand((p) => p.allPaths).toList());
  }

  /* ------------------------------- Photos ------------------------------ */

  static Iterable<String> _photoPaths(Map<String, dynamic> row) => [row['storage_path'] as String, ?(row['thumb_path'] as String?)];

  /// Uploads an already compressed JPEG into the user's private folder.
  Future<String> uploadImage(Uint8List bytes, {String? path}) async {
    path ??= '$uid/${_randomId()}.jpg';
    await sb.storage
        .from(photosBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    return path;
  }

  Future<void> _removeFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await sb.storage.from(photosBucket).remove(paths);
    } catch (_) {
      // orphan files are harmless; never block the user on this
    }
  }

  Future<String> signedUrl(String path) => sb.storage.from(photosBucket).createSignedUrl(path, 3600);

  /// Contact gallery: photos on the contact + photos of its rendezvous
  /// (including the ones friends added to shared rendezvous).
  Future<List<Photo>> listPhotosForContact(String contactId) async {
    final direct = await sb.from('photos').select().eq('contact_id', contactId);
    final links = await sb.from('contact_rendezvous').select('rendezvous_id').eq('contact_id', contactId);
    final ids = links.map((l) => l['rendezvous_id'] as String).toList();
    final all = <String, Photo>{for (final p in direct.map(Photo.fromJson)) p.id: p};
    if (ids.isNotEmpty) {
      final viaRdv = await sb.from('photos').select().inFilter('rendezvous_id', ids);
      for (final p in viaRdv.map(Photo.fromJson)) {
        all[p.id] = p;
      }
      final sharedRdv = await sb.from('rendezvous').select('id').inFilter('id', ids).not('event_id', 'is', null);
      final shared = await Future.wait(sharedRdv.map((r) => listSharedPhotosForRdv(r['id'] as String).catchError((_) => <Photo>[])));
      for (final p in shared.expand((l) => l)) {
        all[p.id] = p;
      }
    }
    return all.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Photos added by the OTHER participants of a shared rendezvous (read-only).
  Future<List<Photo>> listSharedPhotosForRdv(String rdvId) async {
    final rows = await sb.rpc('list_shared_rdv_photos', params: {'p_rdv': rdvId}) as List;
    return rows.map((r) => Photo.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Compresses (720 px + 256 px thumbnail), uploads both, then records the photo.
  Future<Photo> addPhoto(Uint8List raw, {String? contactId, String? rdvId}) async {
    final c = await compressPhoto(raw);
    final id = _randomId();
    final path = await uploadImage(c.full, path: '$uid/$id.jpg');
    String? thumb;
    try {
      thumb = await uploadImage(c.thumb, path: '$uid/${id}_t.jpg');
      final row = await sb
          .from('photos')
          .insert({'user_id': uid, 'contact_id': contactId, 'rendezvous_id': rdvId, 'storage_path': path, 'thumb_path': thumb})
          .select()
          .single();
      return Photo.fromJson(row);
    } catch (e) {
      await _removeFiles([path, ?thumb]);
      rethrow;
    }
  }

  Future<void> deletePhoto(Photo photo) async {
    await sb.from('photos').delete().eq('id', photo.id);
    await _removeFiles(photo.allPaths);
  }

  /* ------------------------------- Friends ----------------------------- */

  Future<List<Friend>> listFriends() async {
    final rows = await sb.rpc('list_friends') as List;
    return rows.map((r) => Friend.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final rows = await sb.rpc('search_users', params: {'p_query': query}) as List;
    return rows.map((r) => UserSearchResult.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// [contactId]: my contact this request is for; linked automatically once accepted.
  Future<FriendRequestResult> sendFriendRequest(String username, {String? contactId}) async {
    final res = await sb.rpc('send_friend_request', params: {'p_username': username.trim(), 'p_contact': ?contactId});
    return FriendRequestResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<void> respondFriendRequest(String friendshipId, bool accept) =>
      sb.rpc('respond_friend_request', params: {'p_id': friendshipId, 'p_accept': accept});

  /// Removes a friend or cancels a sent request. Linked contacts are kept (unlinked).
  Future<void> removeFriend(String friendshipId) => sb.from('friendships').delete().eq('id', friendshipId);

  /// Links a friend to one of my contacts (one contact per friend).
  Future<void> linkFriendToContact(String friendUserId, String contactId) async {
    await sb.from('contacts').update({'linked_user_id': null}).eq('linked_user_id', friendUserId).neq('id', contactId);
    await sb.from('contacts').update({'linked_user_id': friendUserId}).eq('id', contactId);
  }

  Future<void> unlinkFriend(String friendUserId) =>
      sb.from('contacts').update({'linked_user_id': null}).eq('linked_user_id', friendUserId);

  /// "Envie de se voir": one per friend per 24 h.
  Future<void> sendWave(String friendUserId) => sb.rpc('send_wave', params: {'p_to': friendUserId});

  /* ---------------------------- Shared rdv ----------------------------- */

  Future<void> sendRdvInvite(String rdvId, String friendUserId) =>
      sb.rpc('send_rdv_invite', params: {'p_rdv': rdvId, 'p_to': friendUserId});

  Future<List<RdvInvitation>> listInvitesForRdv(String rdvId) async {
    final rows = await sb.from('rdv_invitations').select().or('rdv_id.eq.$rdvId,to_rdv_id.eq.$rdvId');
    return rows.map(RdvInvitation.fromJson).toList();
  }

  Future<void> cancelRdvInvite(String inviteId) => sb.from('rdv_invitations').delete().eq('id', inviteId);

  Future<List<IncomingInvite>> listIncomingInvites() async {
    final rows = await sb.rpc('list_rdv_invites') as List;
    return rows.map((r) => IncomingInvite.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// À confirmer / accepter / refuser; returns the id of MY copy of the rendezvous.
  Future<String?> respondRdvInvite(String inviteId, Rsvp answer) async {
    final res = await sb.rpc('respond_rdv_invite', params: {'p_invite': inviteId, 'p_status': answer.name});
    return res as String?;
  }

  /* ---------------------------- Notifications -------------------------- */

  Future<List<NotificationEntry>> listNotifications({int limit = 10}) async {
    final rows = await sb.from('notifications').select().not('title', 'is', null).order('created_at', ascending: false).limit(limit);
    return rows.map(NotificationEntry.fromJson).toList();
  }

  Future<void> registerDevice(String token, String platform) =>
      sb.rpc('register_device', params: {'p_token': token, 'p_platform': platform});

  Future<void> unregisterDevice(String token) => sb.from('device_tokens').delete().eq('token', token);

  Future<void> sendTestNotification() => sb.rpc('send_test_notification');

  /* ------------------------------ Account ------------------------------ */

  /// Everything the user owns, for "Exporter mes données".
  Future<Map<String, dynamic>> exportData() async {
    final results = await Future.wait([
      sb.from('profiles').select().eq('id', uid).maybeSingle(),
      sb.from('contacts').select().order('name'),
      sb.from('rendezvous').select().order('appointment_at'),
      sb.from('contact_rendezvous').select('contact_id, rendezvous_id'),
      sb.from('photos').select(),
    ]);
    return {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'app': 'SeeU',
      'user': {'id': uid, 'email': sb.auth.currentUser?.email},
      'profile': results[0],
      'contacts': results[1],
      'rendezvous': results[2],
      'contact_rendezvous': results[3],
      'photos': results[4],
    };
  }

  Future<void> deleteAccount() async {
    final res = await sb.functions.invoke('delete-account', method: HttpMethod.post);
    if (res.status != 200) throw AppException(tr.errDeleteAccountFailed);
    await sb.auth.signOut();
  }
}
