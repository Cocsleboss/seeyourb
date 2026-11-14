// Data models — mirror of the Postgres schema (supabase/migrations).
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
  planifie('Planifié'),
  valide('A eu lieu'),
  annule('Annulé');

  const RdvStatus(this.label);
  final String label;

  static RdvStatus parse(String? s) => RdvStatus.values.firstWhere((v) => v.name == s, orElse: () => RdvStatus.planifie);
}

DateTime? _day(dynamic v) => v == null ? null : parseDay(v as String);
DateTime? _ts(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
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
    this.notifyPush = true,
    this.notifyEmail = true,
    this.dailyHour = 8,
    this.dueLeadDays = 0,
    this.rdvReminderMinutes = 30,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? username;
  final DateTime? birthday;
  final String timezone;
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
        birthday: _day(j['birthday']),
        timezone: (j['timezone'] as String?) ?? 'Europe/Paris',
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
    this.category,
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    required this.lastMeetingDate,
    required this.frequencyValue,
    required this.frequencyUnit,
    required this.nextDueDate,
    this.snoozeUntil,
    this.seeSoon = false,
    this.linkedUserId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? photoPath;
  final String? category;
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? notes;
  final DateTime lastMeetingDate;
  final int frequencyValue;
  final FrequencyUnit frequencyUnit;
  @override
  final DateTime nextDueDate;
  @override
  final DateTime? snoozeUntil;
  final bool seeSoon;
  final String? linkedUserId;
  final DateTime? createdAt;

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        name: j['name'] as String,
        photoPath: j['photo_path'] as String?,
        category: _str(j['category']),
        phone: _str(j['phone']),
        email: _str(j['email']),
        birthday: _day(j['birthday']),
        notes: _str(j['notes']),
        lastMeetingDate: parseDay(j['last_meeting_date'] as String),
        frequencyValue: j['frequency_value'] as int,
        frequencyUnit: FrequencyUnit.parse(j['frequency_unit'] as String?),
        nextDueDate: parseDay(j['next_due_date'] as String),
        snoozeUntil: _day(j['snooze_until']),
        seeSoon: (j['see_soon'] as bool?) ?? false,
        linkedUserId: j['linked_user_id'] as String?,
        createdAt: _ts(j['created_at']),
      );

  ContactLite get lite => ContactLite(id: id, name: name, photoPath: photoPath, category: category, linkedUserId: linkedUserId);
}

/// Editable fields of a contact (form + import).
class ContactInput {
  ContactInput({
    required this.name,
    this.category,
    this.phone,
    this.email,
    this.birthday,
    this.notes,
    required this.lastMeetingDate,
    this.frequencyValue = 1,
    this.frequencyUnit = FrequencyUnit.months,
    this.linkedUserId,
  });

  String name;
  String? category;
  String? phone;
  String? email;
  DateTime? birthday;
  String? notes;
  DateTime lastMeetingDate;
  int frequencyValue;
  FrequencyUnit frequencyUnit;
  String? linkedUserId;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'category': _str(category),
        'phone': _str(phone),
        'email': _str(email),
        'birthday': birthday == null ? null : dayIso(birthday!),
        'notes': _str(notes),
        'last_meeting_date': dayIso(lastMeetingDate),
        'frequency_value': frequencyValue,
        'frequency_unit': frequencyUnit.name,
        'linked_user_id': ?linkedUserId,
      };
}

class ContactLite {
  ContactLite({required this.id, required this.name, this.photoPath, this.category, this.linkedUserId});
  final String id;
  final String name;
  final String? photoPath;
  final String? category;
  final String? linkedUserId;

  factory ContactLite.fromJson(Map<String, dynamic> j) => ContactLite(
        id: j['id'] as String,
        name: j['name'] as String,
        photoPath: j['photo_path'] as String?,
        category: _str(j['category']),
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
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? contactId;
  final String? rendezvousId;
  final String storagePath;
  final String? caption;
  final DateTime createdAt;

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        contactId: j['contact_id'] as String?,
        rendezvousId: j['rendezvous_id'] as String?,
        storagePath: j['storage_path'] as String,
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
    this.shareId,
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
  final String? shareId;
  final List<ContactLite> contacts;
  final List<Photo> photos;

  bool get isShared => shareId != null;

  /// Planned and its time passed more than 30 minutes ago → "à confirmer".
  bool needsConfirmation([DateTime? now]) =>
      status == RdvStatus.planifie &&
      appointmentAt.isBefore((now ?? DateTime.now()).subtract(const Duration(minutes: 30)));

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
      shareId: j['share_id'] as String?,
      contacts: contacts,
      photos: photos,
    );
  }
}

String rdvTitle(String? title, List<String> names) {
  final t = _str(title);
  if (t != null) return t;
  if (names.isEmpty) return 'Rendez-vous';
  if (names.length <= 3) return 'Avec ${names.join(', ')}';
  return 'Avec ${names.take(2).join(', ')} et ${names.length - 2} autres';
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
    this.email,
    required this.accepted,
    required this.incoming,
  });
  final String friendshipId;
  final String userId;
  final String? username;
  final String displayName;
  final String? email;
  final bool accepted;

  /// true = request I received; false = request I sent.
  final bool incoming;

  factory Friend.fromJson(Map<String, dynamic> j) => Friend(
        friendshipId: j['friendship_id'] as String,
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: (j['display_name'] as String?) ?? '',
        email: j['email'] as String?,
        accepted: j['status'] == 'accepted',
        incoming: (j['incoming'] as bool?) ?? false,
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
    required this.fromUser,
    required this.fromName,
    this.title,
    this.location,
    required this.appointmentAt,
    required this.rdvStatus,
  });
  final String id;
  final String rdvId;
  final String fromUser;
  final String fromName;
  final String? title;
  final String? location;
  final DateTime appointmentAt;
  final RdvStatus rdvStatus;

  factory IncomingInvite.fromJson(Map<String, dynamic> j) => IncomingInvite(
        id: j['id'] as String,
        rdvId: j['rdv_id'] as String,
        fromUser: j['from_user'] as String,
        fromName: (j['from_name'] as String?) ?? 'Un ami',
        title: _str(j['title']),
        location: _str(j['location']),
        appointmentAt: DateTime.parse(j['appointment_at'] as String).toLocal(),
        rdvStatus: RdvStatus.parse(j['rdv_status'] as String?),
      );
}

const categorySuggestions = ['Famille', 'Amis', 'Pro', 'Autre'];

class FrequencyPreset {
  const FrequencyPreset(this.label, this.value, this.unit);
  final String label;
  final int value;
  final FrequencyUnit unit;
}

const frequencyPresets = [
  FrequencyPreset('1 semaine', 1, FrequencyUnit.weeks),
  FrequencyPreset('2 semaines', 2, FrequencyUnit.weeks),
  FrequencyPreset('1 mois', 1, FrequencyUnit.months),
  FrequencyPreset('2 mois', 2, FrequencyUnit.months),
  FrequencyPreset('3 mois', 3, FrequencyUnit.months),
  FrequencyPreset('6 mois', 6, FrequencyUnit.months),
  FrequencyPreset('1 an', 1, FrequencyUnit.years),
];
