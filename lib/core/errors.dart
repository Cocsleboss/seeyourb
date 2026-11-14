import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception carrying a French, user-facing message.
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns any error into a short French message for toasts and error cards.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is AuthException) return translateAuthError(error.message);
  if (error is PostgrestException) return translateDbError(error.message);
  if (error is StorageException) return translateDbError(error.message);
  if (error is SocketException || error is HttpException) return 'Pas de connexion. Vérifiez votre réseau.';
  final s = error.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
    return 'Pas de connexion. Vérifiez votre réseau.';
  }
  return 'Une erreur est survenue.';
}

String translateDbError(String msg) {
  final m = msg.toLowerCase();
  if (m.contains('failed to fetch') || m.contains('network')) return 'Pas de connexion. Vérifiez votre réseau.';
  if (m.contains('jwt') || m.contains('not authenticated') || m.contains('refresh_token')) return 'Session expirée, reconnectez-vous.';
  if (m.contains('row-level security')) return 'Action non autorisée.';
  if (m.contains('idx_profiles_username')) return "Ce nom d'utilisateur est déjà pris.";
  if (m.contains('profiles_username_format')) return "Nom d'utilisateur invalide.";
  if (m.contains('idx_contacts_linked_user')) return 'Cet ami est déjà associé à un autre contact.';
  if (m.contains('duplicate key')) return 'Cet élément existe déjà.';
  if (m.contains('payload too large') || m.contains('maximum allowed size')) return 'Fichier trop volumineux (10 Mo max).';
  return msg;
}

String translateAuthError(String msg) {
  final m = msg.toLowerCase();
  if (m.contains('invalid login credentials') || m.contains('invalid_credentials')) return 'Email ou mot de passe incorrect.';
  if (m.contains('email not confirmed')) return 'Confirmez d\'abord votre adresse email (lien reçu par mail).';
  if (m.contains('already registered') || m.contains('already been registered') || m.contains('user_already_exists')) {
    return 'Un compte existe déjà avec cet email.';
  }
  if (m.contains('password should be at least') || m.contains('weak_password') || m.contains('password is too short')) {
    return 'Le mot de passe doit contenir au moins 6 caractères.';
  }
  if (m.contains('rate limit') || m.contains('too many requests') || m.contains('over_email_send_rate_limit') || m.contains('security purposes')) {
    return 'Trop de tentatives, réessayez dans quelques minutes.';
  }
  if (m.contains('signups not allowed') || (m.contains('signup') && m.contains('disabled'))) return 'Les inscriptions sont désactivées.';
  if (m.contains('invalid email') || m.contains('validate email') || m.contains('unable to validate')) return 'Adresse email invalide.';
  if (m.contains('same password') || m.contains('different from the old')) return 'Choisissez un mot de passe différent de l\'ancien.';
  if (m.contains('expired') || m.contains('otp') || m.contains('invalid flow state') || m.contains('code verifier')) {
    return 'Lien invalide ou expiré.';
  }
  if (m.contains('session') && m.contains('missing')) return 'Session expirée, reconnectez-vous.';
  if (m.contains('network') || m.contains('socket')) return 'Pas de connexion. Vérifiez votre réseau.';
  return msg;
}
