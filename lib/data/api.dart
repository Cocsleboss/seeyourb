// Data access. Every query goes through Supabase RLS: a user only sees their rows.
// Methods throw; UI catches and shows errorMessage(e) in a toast.
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../domain/dates.dart';
import '../domain/models.dart';

const _rdvSelect = '*, contact_rendezvous(contacts(id, name, photo_path, category, linked_user_id)), photos(*)';
const photosBucket = 'photos';

String _randomId() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class Api {
  Api(this.sb);
  final SupabaseClient sb;

  String get uid {
    final id = sb.auth.currentUser?.id;
    if (id == null) throw AppException('Session expirée, reconnectez-vous.');
    return id;
  }

  /* ------------------------------ Profile ------------------------------ */

  Future<Profile?> getProfile() async {
    final row = await sb.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  /// Gets the profile (creates it if missing) and syncs the device timezone.
  Future<Profile> ensureProfile(String timezone) async {
    final user = sb.auth.currentUser!;
    var profile = await getProfile();
    if (profile == null) {
      final row = await sb
          .from('profiles')
          .upsert({'id': user.id, 'email': user.email, 'display_name': user.email?.split('@').first, 'timezone': timezone})
          .select()
          .single();
      return Profile.fromJson(row);
    }
    if (profile.timezone != timezone || (profile.email == null && user.email != null)) {
      final row = await sb
          .from('profiles')
          .update({'timezone': timezone, 'email': profile.email ?? user.email})
          .eq('id', user.id)
          .select()
          .single();
      profile = Profile.fromJson(row);
    }
    return profile;
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
        if (created > 0) throw AppException('$created contact(s) ajouté(s) avant l\'erreur : ${errorMessage(e)}');
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
    final photos = await sb.from('photos').select('storage_path').eq('contact_id', contact.id);
    final rdvLinks = await sb.from('contact_rendezvous').select('rendezvous_id').eq('contact_id', contact.id);
    final rdvIds = rdvLinks.map((l) => l['rendezvous_id'] as String).toList();
    final paths = [...photos.map((p) => p['storage_path'] as String), ?contact.photoPath];
    // Rendezvous whose only participant is this contact go away with it.
    if (rdvIds.isNotEmpty) {
      final others = await sb.from('contact_rendezvous').select('rendezvous_id').inFilter('rendezvous_id', rdvIds).neq('contact_id', contact.id);
      final shared = others.map((o) => o['rendezvous_id'] as String).toSet();
      final orphan = rdvIds.where((id) => !shared.contains(id)).toList();
      if (orphan.isNotEmpty) {
        final rdvPhotos = await sb.from('photos').select('storage_path').inFilter('rendezvous_id', orphan);
        paths.addAll(rdvPhotos.map((p) => p['storage_path'] as String));
        await sb.from('rendezvous').delete().inFilter('id', orphan);
      }
    }
    await sb.from('contacts').delete().eq('id', contact.id);
    await _removeFiles(paths);
  }

  Future<Contact> setContactPhoto(Contact contact, Uint8List? bytes) async {
    final newPath = bytes == null ? null : await uploadImage(bytes);
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
    final rows = await sb.from('rendezvous').select(_rdvSelect).eq('status', 'planifie').order('appointment_at');
    return rows.map(Rendezvous.fromJson).toList();
  }

  Future<List<Rendezvous>> listHistory({int limit = 200}) async {
    final rows = await sb
        .from('rendezvous')
        .select(_rdvSelect)
        .inFilter('status', ['valide', 'annule'])
        .order('appointment_at', ascending: false)
        .limit(limit);
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
    if (rdv == null) throw AppException('Rendez-vous introuvable');
    return rdv;
  }

  Future<Rendezvous> setRdvStatus(String id, RdvStatus status) => updateRdv(id, {'status': status.name});

  Future<void> deleteRdv(Rendezvous rdv) async {
    await sb.from('rendezvous').delete().eq('id', rdv.id);
    await _removeFiles(rdv.photos.map((p) => p.storagePath).toList());
  }

  /* ------------------------------- Photos ------------------------------ */

  /// Uploads an already resized JPEG into the user's private folder.
  Future<String> uploadImage(Uint8List bytes) async {
    final path = '$uid/${_randomId()}.jpg';
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
      final sharedRdv = await sb.from('rendezvous').select('id').inFilter('id', ids).not('share_id', 'is', null);
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

  Future<Photo> addPhoto(Uint8List bytes, {String? contactId, String? rdvId}) async {
    final path = await uploadImage(bytes);
    try {
      final row = await sb
          .from('photos')
          .insert({'user_id': uid, 'contact_id': contactId, 'rendezvous_id': rdvId, 'storage_path': path})
          .select()
          .single();
      return Photo.fromJson(row);
    } catch (e) {
      await _removeFiles([path]);
      rethrow;
    }
  }

  Future<void> deletePhoto(Photo photo) async {
    await sb.from('photos').delete().eq('id', photo.id);
    await _removeFiles([photo.storagePath]);
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

  Future<FriendRequestResult> sendFriendRequest(String username) async {
    final res = await sb.rpc('send_friend_request', params: {'p_username': username.trim()});
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

  /// Accept → id of MY copy of the rendezvous; decline → null.
  Future<String?> respondRdvInvite(String inviteId, bool accept) async {
    final res = await sb.rpc('respond_rdv_invite', params: {'p_invite': inviteId, 'p_accept': accept});
    return res as String?;
  }

  /* ---------------------------- Notifications -------------------------- */

  Future<List<NotificationEntry>> listNotifications({int limit = 10}) async {
    final rows = await sb.from('notifications').select().order('created_at', ascending: false).limit(limit);
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
    if (res.status != 200) throw AppException('Suppression impossible pour le moment. Réessayez plus tard.');
    await sb.auth.signOut();
  }
}
