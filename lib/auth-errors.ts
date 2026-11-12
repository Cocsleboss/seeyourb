/** Traduit les messages d'erreur de Supabase Auth en français. */
export function translateAuthError(msg: string): string {
  const m = msg.toLowerCase();
  if (m.includes("invalid login credentials") || m.includes("invalid_credentials")) return "Email ou mot de passe incorrect.";
  if (m.includes("email not confirmed")) return "Confirmez d'abord votre adresse email (lien reçu par mail).";
  if (m.includes("already registered") || m.includes("already been registered") || m.includes("user_already_exists"))
    return "Un compte existe déjà avec cet email.";
  if (m.includes("password should be at least") || m.includes("weak_password") || m.includes("password is too short"))
    return "Le mot de passe doit contenir au moins 6 caractères.";
  if (
    m.includes("rate limit") ||
    m.includes("too many requests") ||
    m.includes("over_email_send_rate_limit") ||
    m.includes("security purposes")
  )
    return "Trop de tentatives, réessayez dans quelques minutes.";
  if (m.includes("signups not allowed") || (m.includes("signup") && m.includes("disabled"))) return "Les inscriptions sont désactivées.";
  if (m.includes("failed to fetch") || m.includes("network")) return "Pas de connexion. Vérifiez votre réseau.";
  if (m.includes("invalid email") || m.includes("validate email") || m.includes("unable to validate")) return "Adresse email invalide.";
  if (m.includes("same password") || m.includes("different from the old")) return "Choisissez un mot de passe différent de l'ancien.";
  if (m.includes("session") && m.includes("missing")) return "Session expirée, reconnectez-vous.";
  return msg;
}
