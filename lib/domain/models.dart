// Data models — mirror of the Postgres schema (supabase/migrations).
import '../core/i18n.dart';
import 'dates.dart';
import 'text.dart';

enum FrequencyUnit {
  days,
  weeks,
  months,
  years;

  static FrequencyUnit parse(String? s) =>
      FrequencyUnit.values.firstWhere((u) => u.name == s, orElse: () => FrequencyUnit.months);
}

enum RdvStatus {
  planifie,
  valide,
  annule;

  String get label => switch (this) {
        planifie => tr.statusPlanned,
        valide => tr.statusDone,
        annule => tr.statusCancelled,
      };

  static RdvStatus parse(String? s) => RdvStatus.values.firstWhere((v) => v.name == s, orElse: () => RdvStatus.planifie);
}

/// Displayed status: planned events become "en cours" then "passé" with time.
enum RdvPhase {
  upcoming,
  now,
  past,
  done,
  cancelled;

  String get label => switch (this) {
        upcoming => tr.phaseUpcoming,
        now => tr.phaseNow,
        past => tr.phasePast,
        done => tr.statusDone,
        cancelled => tr.statusCancelled,
      };
}

DateTime? _day(dynamic v) => v == null ? null : parseDay(v as String);
DateTime? _ts(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
List<String> _strList(dynamic v) =>
    ((v as List?) ?? const []).map((e) => (e as String).trim()).where((e) => e.isNotEmpty).toList();

String? _str(dynamic v) {
  if (v == null) return null;
  final s = (v as String).trim();
  return s.isEmpty ? null : s;
}

class Profile {
  Profile({
    required this.id,
    this.email,
    this.displayName,
    this.username,
    this.birthday,
    this.timezone = 'Europe/Paris',
    this.locale = 'fr',
    this.notifyPush = true,
    this.notifyEmail = true,
    this.dailyHour = 8,
    this.dueLeadDays = 0,
    this.rdvReminderMinutes = 30,
    this.avatarPath,
  });

  final String id;

  /// SeeU profile picture (public "avatars" bucket).
  final String? avatarPath;
  final String? email;
  final String? displayName;
  final String? username;
  final DateTime? birthday;
  final String timezone;

  /// Language of the notifications ('fr', 'en').
  final String locale;
  final bool notifyPush;
  final bool notifyEmail;
  final int dailyHour;
  final int dueLeadDays;
  final int rdvReminderMinutes;

  /// Name shown in greetings: display name, else username, else email prefix.
  String get name => _str(displayName) ?? username ?? (email?.split('@').first ?? '');

  String get firstName => name.split(RegExp(r'\s+')).first;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: j['email'] as String?,
        displayName: j['display_name'] as String?,
        username: j['username'] as String?,
        avatarPath: j['avatar_path'] as String?,
        birthday: _day(j['birthday']),
        timezone: (j['timezone'] as String?) ?? 'Europe/Paris',
        locale: (j['locale'] as String?) ?? 'fr',
        notifyPush: (j['notify_push'] as bool?) ?? true,
        notifyEmail: (j['notify_email'] as bool?) ?? true,
        dailyHour: (j['daily_hour'] as int?) ?? 8,
        dueLeadDays: (j['due_lead_days'] as int?) ?? 0,
        rdvReminderMinutes: (j['rdv_reminder_minutes'] as int?) ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'username': username,
        'birthday': birthday == null ? null : dayIso(birthday!),
        'timezone': timezone,
        'notify_push': notifyPush,
        'notify_email': notifyEmail,
        'daily_hour': dailyHour,
        'due_lead_days': dueLeadDays,
        'rdv_reminder_minutes': rdvReminderMinutes,
      };
}

/// Anything that has a due date (contacts, light contacts for computations).
abstract interface class HasDue {
  DateTime get nextDueDate;
  DateTime? get snoozeUntil;
}

class Contact implements HasDue {
  Contact({
    required this.id,
    required this.userId,
    required this.name,
    this.photoPath,
    this.categories = const [],
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    this.lastMeetingDate,
    required this.frequencyValue,
    required this.frequencyUnit,
    required this.nextDueDate,
    this.snoozeUntil,
    this.seeSoon = false,
    this.linkedUserId,
    this.createdAt,
    this.addedOn,
  });

  final String id;
  final String userId;
  final String name;
  final String? photoPath;
  final List<String> categories;
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? notes;

  /// null = no meeting recorded yet (due date counts from the day the contact was added).
  final DateTime? lastMeetingDate;
  final int frequencyValue;
  final FrequencyUnit frequencyUnit;
  @override
  final DateTime nextDueDate;
  @override
  final DateTime? snoozeUntil;
  final bool seeSoon;
  final String? linkedUserId;
  final DateTime? createdAt;

  /// Day the contact was added: start of the first period when no meeting is recorded.
  final DateTime? addedOn;

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        photoPath: j['photo_path'] as String?,
        categories: _strList(j['categories']),
        phone: _str(j['phone']),
        email: _str(j['email']),
        birthday: _day(j['birthday']),
        notes: _str(j['notes']),
        lastMeetingDate: _day(j['last_meeting_date']),
        frequencyValue: j['frequency_value'] as int,
        frequencyUnit: FrequencyUnit.parse(j['frequency_unit'] as String?),
        nextDueDate: parseDay(j['next_due_date'] as String),
        snoozeUntil: _day(j['snooze_until']),
        seeSoon: (j['see_soon'] as bool?) ?? false,
        linkedUserId: j['linked_user_id'] as String?,
        createdAt: _ts(j['created_at']),
        addedOn: _day(j['added_on']),
      );

  ContactLite get lite => ContactLite(id: id, name: name, photoPath: photoPath, categories: categories, linkedUserId: linkedUserId);

  /// "Amis · Pro"
  String? get categoryLabel => categories.isEmpty ? null : categories.join(' · ');
}

/// Editable fields of a contact (form + import).
class ContactInput {
  ContactInput({
    required this.name,
    this.categories = const [],
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    this.lastMeetingDate,
    this.frequencyValue = 1,
    this.frequencyUnit = FrequencyUnit.months,
    this.linkedUserId,
  });

  String name;
  List<String> categories;
  String? phone;
  String? email;
  DateTime? birthday;
  String? notes;
  DateTime? lastMeetingDate;
  int frequencyValue;
  FrequencyUnit frequencyUnit;
  String? linkedUserId;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'categories': categories.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList(),
        'phone': _str(phone),
        'email': _str(email),
        'birthday': birthday == null ? null : dayIso(birthday!),
        'notes': _str(notes),
        'last_meeting_date': lastMeetingDate == null ? null : dayIso(lastMeetingDate!),
        'frequency_value': frequencyValue,
        'frequency_unit': frequencyUnit.name,
        'linked_user_id': ?linkedUserId,
      };
}

class ContactLite {
  ContactLite({required this.id, required this.name, this.photoPath, this.categories = const [], this.linkedUserId});
  final String id;
  final String name;
  final String? photoPath;
  final List<String> categories;
  final String? linkedUserId;

  String? get categoryLabel => categories.isEmpty ? null : categories.join(' · ');

  factory ContactLite.fromJson(Map<String, dynamic> j) => ContactLite(
        id: j['id'] as String,
        name: j['name'] as String,
        photoPath: j['photo_path'] as String?,
        categories: _strList(j['categories']),
        linkedUserId: j['linked_user_id'] as String?,
      );
}

class Photo {
  Photo({
    required this.id,
    required this.userId,
    this.contactId,
    this.rendezvousId,
    required this.storagePath,
    this.thumbPath,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? contactId;
  final String? rendezvousId;
  final String storagePath;

  /// Small version for grids (null for photos uploaded before thumbnails existed).
  final String? thumbPath;
  final String? caption;

  String get previewPath => thumbPath ?? storagePath;
  List<String> get allPaths => [storagePath, ?thumbPath];
  final DateTime createdAt;

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        contactId: j['contact_id'] as String?,
        rendezvousId: j['rendezvous_id'] as String?,
        storagePath: j['storage_path'] as String,
        thumbPath: j['thumb_path'] as String?,
        caption: j['caption'] as String?,
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );
}

class Rendezvous {
  Rendezvous({
    required this.id,
    required this.userId,
    this.title,
    this.location,
    this.notes,
    required this.appointmentAt,
    required this.status,
    this.eventId,
    this.event,
    this.rsvp,
    this.chatReadAt,
    this.contacts = const [],
    this.photos = const [],
  });

  final String id;
  final String userId;
  final String? title;
  final String? location;
  final String? notes;
  final DateTime appointmentAt;
  final RdvStatus status;

  /// The shared event this copy belongs to (null: personal entry, e.g. "Vu").
  final String? eventId;
  final EventInfo? event;

  /// Only on someone else's event: à confirmer / accepté / refusé.
  final Rsvp? rsvp;
  final DateTime? chatReadAt;
  final List<ContactLite> contacts;
  final List<Photo> photos;

  /// Other people take part (or can join).
  bool get isShared => event != null && (event!.memberCount > 1 || event!.visibility != EventVisibility.private);
  bool get isTentative => rsvp == Rsvp.pending;
  bool get isOrganizer => event == null || event!.organizerId == userId;
  bool get slotsOpen => event?.slotsOpen ?? false;
  EventVisibility get visibility => event?.visibility ?? EventVisibility.private;

  /// Planned and its time passed more than 30 minutes ago → "à confirmer".
  /// What to show as status: derived from the time while planned.
  RdvPhase phase([DateTime? now]) {
    if (status == RdvStatus.valide) return RdvPhase.done;
    if (status == RdvStatus.annule) return RdvPhase.cancelled;
    final t = now ?? DateTime.now();
    if (slotsOpen || appointmentAt.isAfter(t)) return RdvPhase.upcoming;
    if (t.isBefore(appointmentAt.add(const Duration(hours: 3)))) return RdvPhase.now;
    return RdvPhase.past;
  }

  /// "Has it happened?" — same moment the status turns to "Passé".
  /// Only the organizer says whether it happened (it's the same for everyone).
  bool needsConfirmation([DateTime? now]) => isOrganizer && phase(now) == RdvPhase.past;

  /// Title, or "Avec Marie, Paul" / "Avec Marie, Paul et 2 autres".
  String get displayTitle => rdvTitle(title, contacts.map((c) => c.name).toList());

  factory Rendezvous.fromJson(Map<String, dynamic> j) {
    final links = (j['contact_rendezvous'] as List?) ?? const [];
    final contacts = links
        .map((l) => (l as Map)['contacts'])
        .whereType<Map<String, dynamic>>()
        .map(ContactLite.fromJson)
        .toList()
      ..sort((a, b) => compareNames(a.name, b.name));
    final photos = ((j['photos'] as List?) ?? const [])
        .map((p) => Photo.fromJson(p as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Rendezvous(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: _str(j['title']),
      location: _str(j['location']),
      notes: _str(j['notes']),
      appointmentAt: DateTime.parse(j['appointment_at'] as String).toLocal(),
      status: RdvStatus.parse(j['status'] as String?),
      eventId: j['event_id'] as String?,
      event: j['events'] is Map<String, dynamic> ? EventInfo.fromJson(j['events'] as Map<String, dynamic>) : null,
      rsvp: Rsvp.parse(j['rsvp'] as String?),
      chatReadAt: _ts(j['chat_read_at']),
      contacts: contacts,
      photos: photos,
    );
  }
}

/// Who can see an event.
enum EventVisibility {
  private,
  contacts,
  public;

  static EventVisibility parse(String? s) => values.where((v) => v.name == s).firstOrNull ?? private;

  String get label => switch (this) {
        private => tr.visPrivate,
        contacts => tr.visContacts,
        public => tr.visPublic,
      };
}

/// Shared part of a rendezvous (embedded in the copy).
class EventInfo {
  EventInfo({
    required this.id,
    required this.organizerId,
    this.visibility = EventVisibility.private,
    this.slotsOpen = false,
    this.description,
    this.memberCount = 1,
    this.goingCount = 1,
    this.guestsCanInvite = true,
    this.link,
    this.lat,
    this.lng,
  });
  final String id;
  final String organizerId;

  /// Web link (tickets, menu, meeting page…).
  final String? link;

  /// Place picked on the map (null: free text only).
  final double? lat;
  final double? lng;
  final EventVisibility visibility;
  final bool slotsOpen;
  final String? description;
  final int memberCount;
  final int goingCount;

  /// Participants may invite their own friends.
  final bool guestsCanInvite;

  factory EventInfo.fromJson(Map<String, dynamic> j) => EventInfo(
        id: j['id'] as String,
        organizerId: j['organizer_id'] as String,
        visibility: EventVisibility.parse(j['visibility'] as String?),
        slotsOpen: (j['slots_open'] as bool?) ?? false,
        description: _str(j['description']),
        memberCount: (j['member_count'] as int?) ?? 1,
        goingCount: (j['going_count'] as int?) ?? 1,
        guestsCanInvite: (j['guests_can_invite'] as bool?) ?? true,
        link: _str(j['link']),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

/// An event as listed in the feeds / previewed before joining.
class FeedEvent {
  FeedEvent({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    this.organizerUsername,
    required this.visibility,
    this.title,
    this.location,
    this.description,
    required this.appointmentAt,
    this.status = RdvStatus.planifie,
    this.slotsOpen = false,
    this.going = 1,
    this.myRdvId,
    this.myRsvp,
    this.isMine = false,
    this.canPost = false,
    this.organizerIsFriend = false,
    this.mutedEvent = false,
    this.mutedOrganizer = false,
    this.link,
    this.lat,
    this.lng,
  });
  final String? link;
  final double? lat;
  final double? lng;
  final String id;
  final String organizerId;
  final String organizerName;
  final String? organizerUsername;
  final EventVisibility visibility;
  final String? title;
  final String? location;
  final String? description;
  final DateTime appointmentAt;
  final RdvStatus status;
  final bool slotsOpen;
  final int going;
  final String? myRdvId;
  final Rsvp? myRsvp;
  final bool isMine;
  final bool canPost;
  final bool organizerIsFriend;
  final bool mutedEvent;
  final bool mutedOrganizer;

  /// In my agenda (organizer, going or "à confirmer").
  bool get joined => myRdvId != null && myRsvp != Rsvp.declined;
  String get displayTitle => title ?? tr.eventBy(organizerName);

  factory FeedEvent.fromJson(Map<String, dynamic> j) => FeedEvent(
        id: j['id'] as String,
        organizerId: j['organizer_id'] as String,
        organizerName: (j['organizer_name'] as String?) ?? 'SeeU',
        organizerUsername: j['organizer_username'] as String?,
        visibility: EventVisibility.parse(j['visibility'] as String?),
        title: _str(j['title']),
        location: _str(j['location']),
        description: _str(j['description']),
        appointmentAt: DateTime.parse(j['appointment_at'] as String).toLocal(),
        status: RdvStatus.parse(j['status'] as String?),
        slotsOpen: (j['slots_open'] as bool?) ?? false,
        going: (j['going'] as int?) ?? 1,
        myRdvId: j['my_rdv_id'] as String?,
        myRsvp: Rsvp.parse(j['my_rsvp'] as String?),
        isMine: (j['is_mine'] as bool?) ?? false,
        canPost: (j['can_post'] as bool?) ?? false,
        organizerIsFriend: (j['organizer_is_friend'] as bool?) ?? false,
        mutedEvent: (j['muted_event'] as bool?) ?? false,
        mutedOrganizer: (j['muted_organizer'] as bool?) ?? false,
        link: _str(j['link']),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

class Participant {
  Participant({required this.userId, required this.name, this.username, required this.role, this.isFriend = false});
  final String userId;
  final String name;
  final String? username;

  /// 'organizer' | 'accepted' | 'pending'
  final String role;
  final bool isFriend;

  bool get isOrganizer => role == 'organizer';

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
        userId: j['user_id'] as String,
        name: (j['display_name'] as String?) ?? 'SeeU',
        username: j['username'] as String?,
        role: (j['rsvp'] as String?) ?? 'pending',
        isFriend: (j['is_friend'] as bool?) ?? false,
      );
}

/// Someone without a SeeU account attached to an event by a member (one of their contacts).
class EventGuest {
  EventGuest({this.contactId, required this.name, required this.addedBy, required this.addedByName, this.isMine = false});

  /// Only for my own contacts.
  final String? contactId;
  final String name;
  final String addedBy;
  final String addedByName;
  final bool isMine;

  factory EventGuest.fromJson(Map<String, dynamic> j) => EventGuest(
        contactId: j['contact_id'] as String?,
        name: j['name'] as String,
        addedBy: j['added_by'] as String,
        addedByName: (j['added_by_name'] as String?) ?? 'SeeU',
        isMine: (j['is_mine'] as bool?) ?? false,
      );
}

enum SlotAnswer {
  yes,
  maybe,
  no;

  static SlotAnswer? parse(String? s) => values.where((v) => v.name == s).firstOrNull;
}

class EventSlot {
  EventSlot({
    required this.id,
    required this.startsAt,
    this.yes = 0,
    this.maybe = 0,
    this.no = 0,
    this.myAnswer,
    this.yesNames = const [],
    this.maybeNames = const [],
    this.noNames = const [],
  });
  final String id;
  final DateTime startsAt;
  final int yes;
  final int maybe;
  final int no;
  final SlotAnswer? myAnswer;
  final List<String> yesNames;
  final List<String> maybeNames;
  final List<String> noNames;

  /// Ranking: available people first, "maybe" counts half.
  double get score => yes + maybe * 0.5;

  factory EventSlot.fromJson(Map<String, dynamic> j) => EventSlot(
        id: j['id'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String).toLocal(),
        yes: (j['yes'] as int?) ?? 0,
        maybe: (j['maybe'] as int?) ?? 0,
        no: (j['no'] as int?) ?? 0,
        myAnswer: SlotAnswer.parse(j['my_answer'] as String?),
        yesNames: _strList(j['yes_names']),
        noNames: _strList(j['no_names']),
        maybeNames: _strList(j['maybe_names']),
      );
}

/// Best timeslots (several when tied); empty when nobody voted yet.
List<EventSlot> bestSlots(List<EventSlot> slots) {
  if (slots.isEmpty) return const [];
  final top = slots.map((s) => s.score).reduce((a, b) => a > b ? a : b);
  if (top <= 0) return const [];
  return slots.where((s) => s.score == top).toList();
}

class ChatMessage {
  ChatMessage({required this.id, required this.userId, required this.authorName, required this.body, required this.createdAt});
  final String id;
  final String userId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        authorName: (j['author_name'] as String?) ?? '',
        body: j['body'] as String,
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );
}

class BlockedUser {
  BlockedUser({required this.userId, required this.name, this.username});
  final String userId;
  final String name;
  final String? username;
  factory BlockedUser.fromJson(Map<String, dynamic> j) =>
      BlockedUser(userId: j['user_id'] as String, name: (j['display_name'] as String?) ?? 'SeeU', username: j['username'] as String?);
}

class MuteEntry {
  MuteEntry({required this.id, this.targetUser, this.userName, this.username, this.eventId, this.eventTitle, this.eventAt});
  final String id;
  final String? targetUser;
  final String? userName;
  final String? username;
  final String? eventId;
  final String? eventTitle;
  final DateTime? eventAt;
  bool get isPerson => targetUser != null;

  factory MuteEntry.fromJson(Map<String, dynamic> j) => MuteEntry(
        id: j['id'] as String,
        targetUser: j['target_user'] as String?,
        userName: j['user_name'] as String?,
        username: j['username'] as String?,
        eventId: j['event_id'] as String?,
        eventTitle: _str(j['event_title']),
        eventAt: _ts(j['event_at']),
      );
}

/// What the event form sends to save_event.
class EventInput {
  EventInput({
    this.rdvId,
    this.visibility = EventVisibility.private,
    this.title,
    this.location,
    this.description,
    this.notes,
    this.appointmentAt,
    this.status = RdvStatus.planifie,
    this.slots = const [],
    this.contactIds = const [],
    this.inviteUserIds = const [],
    this.guestsCanInvite = true,
    this.link,
    this.lat,
    this.lng,
  });
  String? rdvId;
  String? link;
  double? lat;
  double? lng;
  EventVisibility visibility;
  String? title;
  String? location;
  String? description;
  String? notes;
  DateTime? appointmentAt;
  RdvStatus status;
  List<DateTime> slots;
  List<String> contactIds;
  List<String> inviteUserIds;
  bool guestsCanInvite;

  Map<String, dynamic> toJson() => {
        'rdv_id': ?rdvId,
        'visibility': visibility.name,
        'title': _str(title),
        'location': _str(location),
        'description': _str(description),
        'notes': _str(notes),
        'appointment_at': appointmentAt?.toUtc().toIso8601String(),
        'status': status.name,
        'slots': [for (final s in slots) s.toUtc().toIso8601String()],
        'contact_ids': contactIds.toSet().toList(),
        'invite_user_ids': inviteUserIds.toSet().toList(),
        'guests_can_invite': guestsCanInvite,
        'link': _str(link),
        'lat': lat,
        'lng': lng,
      };
}

/// Answer to an invitation, stored on the invitee's copy.
enum Rsvp {
  pending,
  accepted,
  declined;

  String get label => switch (this) {
        pending => tr.rsvpPending,
        accepted => tr.rsvpAccepted,
        declined => tr.rsvpDeclined,
      };

  static Rsvp? parse(String? s) => s == null ? null : Rsvp.values.where((v) => v.name == s).firstOrNull;
}

String rdvTitle(String? title, List<String> names) {
  final t = _str(title);
  if (t != null) return t;
  if (names.isEmpty) return 'Rendez-vous';
  if (names.length <= 3) return tr.withNames(names.join(', '));
  return tr.withNamesMore(names.take(2).join(', '), names.length - 2);
}

class RdvInput {
  RdvInput({this.title, this.location, this.notes, required this.appointmentAt, this.status});
  String? title;
  String? location;
  String? notes;
  DateTime appointmentAt;
  RdvStatus? status;

  Map<String, dynamic> toJson() => {
        'title': _str(title),
        'location': _str(location),
        'notes': _str(notes),
        'appointment_at': appointmentAt.toUtc().toIso8601String(),
        'status': ?status?.name,
      };
}

class NotificationEntry {
  NotificationEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.url,
    required this.channel,
    required this.createdAt,
  });
  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? url;
  final String channel;
  final DateTime createdAt;

  factory NotificationEntry.fromJson(Map<String, dynamic> j) => NotificationEntry(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        url: j['url'] as String?,
        channel: (j['channel'] as String?) ?? 'none',
        createdAt: _ts(j['created_at']) ?? DateTime.now(),
      );
}

/// A row of list_friends(): accepted friend or pending request.
class Friend {
  Friend({
    required this.friendshipId,
    required this.userId,
    this.username,
    required this.displayName,
    required this.accepted,
    required this.incoming,
    this.contactId,
  });
  final String friendshipId;
  final String userId;
  final String? username;
  final String displayName;
  final bool accepted;

  /// My contact this request was sent for (linked automatically on accept).
  final String? contactId;

  /// true = request I received; false = request I sent.
  final bool incoming;

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        friendshipId: j['friendship_id'] as String,
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        accepted: j['status'] == 'accepted',
        incoming: (j['incoming'] as bool?) ?? false,
        contactId: j['contact_id'] as String?,
      );
}

enum UserRelation { none, friends, sent, received }

class UserSearchResult {
  UserSearchResult({required this.userId, required this.username, required this.displayName, required this.relation});
  final String userId;
  final String username;
  final String displayName;
  final UserRelation relation;

  factory UserSearchResult.fromJson(Map<String, dynamic> j) => UserSearchResult(
        userId: j['user_id'] as String,
        username: j['username'] as String,
        displayName: (j['display_name'] as String?) ?? j['username'] as String,
        relation: UserRelation.values.firstWhere((r) => r.name == j['relation'], orElse: () => UserRelation.none),
      );
}

enum FriendRequestStatus { sent, accepted, alreadySent, alreadyFriends, self, notFound }

class FriendRequestResult {
  FriendRequestResult(this.status, {this.friendshipId, this.userId, this.displayName});
  final FriendRequestStatus status;
  final String? friendshipId;
  final String? userId;
  final String? displayName;

  factory FriendRequestResult.fromJson(Map<String, dynamic> j) {
    const map = {
      'sent': FriendRequestStatus.sent,
      'accepted': FriendRequestStatus.accepted,
      'already_sent': FriendRequestStatus.alreadySent,
      'already_friends': FriendRequestStatus.alreadyFriends,
      'self': FriendRequestStatus.self,
      'not_found': FriendRequestStatus.notFound,
    };
    return FriendRequestResult(
      map[j['status']] ?? FriendRequestStatus.notFound,
      friendshipId: j['friendship_id'] as String?,
      userId: j['user_id'] as String?,
      displayName: j['display_name'] as String?,
    );
  }
}

enum InviteStatus { pending, accepted, declined }

class RdvInvitation {
  RdvInvitation({
    required this.id,
    required this.rdvId,
    required this.fromUser,
    required this.toUser,
    required this.status,
    this.toRdvId,
  });
  final String id;
  final String rdvId;
  final String fromUser;
  final String toUser;
  final InviteStatus status;
  final String? toRdvId;

  factory RdvInvitation.fromJson(Map<String, dynamic> j) => RdvInvitation(
        id: j['id'] as String,
        rdvId: j['rdv_id'] as String,
        fromUser: j['from_user'] as String,
        toUser: j['to_user'] as String,
        status: InviteStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => InviteStatus.pending),
        toRdvId: j['to_rdv_id'] as String?,
      );
}

/// Pending invitation I received, with the proposed rendezvous details.
class IncomingInvite {
  IncomingInvite({
    required this.id,
    required this.rdvId,
    this.toRdvId,
    required this.fromUser,
    required this.fromName,
    this.title,
    this.location,
    required this.appointmentAt,
    required this.rdvStatus,
  });
  final String id;
  final String rdvId;

  /// My tentative copy of the rendezvous.
  final String? toRdvId;
  final String fromUser;
  final String fromName;
  final String? title;
  final String? location;
  final DateTime appointmentAt;
  final RdvStatus rdvStatus;

  factory IncomingInvite.fromJson(Map<String, dynamic> j) => IncomingInvite(
        id: j['id'] as String,
        rdvId: j['rdv_id'] as String,
        toRdvId: j['to_rdv_id'] as String?,
        fromUser: j['from_user'] as String,
        fromName: (j['from_name'] as String?) ?? tr.aFriend,
        title: _str(j['title']),
        location: _str(j['location']),
        appointmentAt: DateTime.parse(j['appointment_at'] as String).toLocal(),
        rdvStatus: RdvStatus.parse(j['rdv_status'] as String?),
      );
}

List<String> get categorySuggestions => [tr.catFamily, tr.catFriends, tr.catWork, tr.catOther];

class FrequencyPreset {
  const FrequencyPreset(this.value, this.unit);
  final int value;
  final FrequencyUnit unit;

  /// "1 semaine", "3 mois", "1 an"
  String get label => switch (unit) {
        FrequencyUnit.days => tr.nDays(value),
        FrequencyUnit.weeks => tr.nWeeks(value),
        FrequencyUnit.months => tr.nMonths(value),
        FrequencyUnit.years => tr.nYears(value),
      };
}

const frequencyPresets = [
  FrequencyPreset(1, FrequencyUnit.weeks),
  FrequencyPreset(2, FrequencyUnit.weeks),
  FrequencyPreset(1, FrequencyUnit.months),
  FrequencyPreset(2, FrequencyUnit.months),
  FrequencyPreset(3, FrequencyUnit.months),
  FrequencyPreset(6, FrequencyUnit.months),
  FrequencyPreset(1, FrequencyUnit.years),
];
