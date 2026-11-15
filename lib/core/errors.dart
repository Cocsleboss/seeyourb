import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'i18n.dart';

/// Exception carrying a user-facing (already translated) message.
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns any error into a short message for toasts and error cards.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthException) return translateAuthError(error.message);
  if (error is PostgrestException) return translateDbError(error.message);
  if (error is StorageException) return translateDbError(error.message);
  if (error is SocketException || error is HttpException) return tr.errNetwork;
  final s = error.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
    return tr.errNetwork;
  }
  return tr.errGeneric;
}

/// Server errors: new SQL raises a stable code ("seeu:not_friends"); older functions
/// raise a French sentence. Both map to the translated message.
String? _serverMessage(String msg) {
  final code = RegExp(r'seeu:([a-z_]+)').firstMatch(msg)?.group(1);
  final m = msg.trim();
  String? is_(String c, String fr) => code == c || m.startsWith(fr) ? c : null;
  final k = is_('not_signed_in', 'Non connecté') ??
      is_('not_friends', 'Cette personne ne fait pas partie') ??
      is_('no_longer_friends', "Vous n'êtes plus amis") ??
      is_('rdv_not_found', 'Rendez-vous introuvable') ??
      is_('invite_not_found', 'Invitation introuvable') ??
      is_('rdv_gone', "Ce rendez-vous n'existe plus") ??
      is_('rdv_cancelled', 'Ce rendez-vous est annulé') ??
      is_('wave_already', 'Vous lui avez déjà fait signe') ??
      is_('already_answered', 'Vous avez déjà répondu') ??
      is_('bad_answer', 'Réponse invalide') ??
      is_('request_not_found', 'Demande introuvable') ??
      code;
  return switch (k) {
    'not_signed_in' => tr.errSessionExpired,
    'not_friends' => tr.errNotFriends,
    'no_longer_friends' => tr.errNoLongerFriends,
    'rdv_not_found' => tr.errRdvNotFound,
    'invite_not_found' => tr.errInviteNotFound,
    'rdv_gone' => tr.errRdvGone,
    'rdv_cancelled' => tr.errRdvCancelled,
    'wave_already' => tr.errWaveAlready,
    'already_answered' => tr.errAlreadyAnswered,
    'bad_answer' => tr.errBadAnswer,
    'request_not_found' => tr.errRequestNotFound,
    'not_organizer' => tr.errNotOrganizer,
    'public_not_allowed' => tr.errPublicNotAllowed,
    'slots_closed' => tr.errSlotsClosed,
    'slots_not_allowed' => tr.errSlotsNotAllowed,
    'too_many_slots' => tr.errTooManySlots,
    'event_not_visible' => tr.errEventNotVisible,
    'blocked' => tr.errBlocked,
    'chat_read_only' => tr.errChatReadOnly,
    'photos_organizer_only' => tr.errPhotosOrganizerOnly,
    'not_participant' => tr.errNotParticipant,
    null => null,
    _ => tr.errGeneric,
  };
}

String translateDbError(String msg) {
  final server = _serverMessage(msg);
  if (server != null) return server;
  final m = msg.toLowerCase();
  if (m.contains('failed to fetch') || m.contains('network')) return tr.errNetwork;
  if (m.contains('jwt') || m.contains('not authenticated') || m.contains('refresh_token')) return tr.errSessionExpired;
  if (m.contains('row-level security')) return tr.errForbidden;
  if (m.contains('idx_profiles_username')) return tr.errUsernameTaken;
  if (m.contains('profiles_username_format')) return tr.errUsernameInvalid;
  if (m.contains('idx_contacts_linked_user')) return tr.errFriendAlreadyLinked;
  if (m.contains('duplicate key')) return tr.errDuplicate;
  if (m.contains('payload too large') || m.contains('maximum allowed size')) return tr.errFileTooLarge;
  return tr.errGeneric;
}

String translateAuthError(String msg) {
  final m = msg.toLowerCase();
  if (m.contains('invalid login credentials') || m.contains('invalid_credentials')) return tr.errBadCredentials;
  if (m.contains('email not confirmed')) return tr.errEmailNotConfirmed;
  if (m.contains('already registered') || m.contains('already been registered') || m.contains('user_already_exists')) {
    return tr.errEmailTaken;
  }
  if (m.contains('password should be at least') || m.contains('weak_password') || m.contains('password is too short')) {
    return tr.errWeakPassword;
  }
  if (m.contains('rate limit') || m.contains('too many requests') || m.contains('over_email_send_rate_limit') || m.contains('security purposes')) {
    return tr.errRateLimit;
  }
  if (m.contains('signups not allowed') || (m.contains('signup') && m.contains('disabled'))) return tr.errSignupsDisabled;
  if (m.contains('invalid email') || m.contains('validate email') || m.contains('unable to validate')) return tr.errInvalidEmail;
  if (m.contains('same password') || m.contains('different from the old')) return tr.errSamePassword;
  // PKCE: the link was opened on another device / app install than the one that asked for it.
  if (m.contains('code verifier')) return tr.errLinkOtherDevice;
  if (m.contains('expired') || m.contains('otp') || m.contains('invalid flow state') || m.contains('flow_state')) {
    return tr.errLinkExpired;
  }
  if (m.contains('session') && m.contains('missing')) return tr.errSessionExpired;
  if (m.contains('network') || m.contains('socket')) return tr.errNetwork;
  return tr.errGeneric;
}
