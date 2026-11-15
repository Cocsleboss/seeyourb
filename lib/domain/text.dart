// Text helpers: accent/case-insensitive search (§5.9), name lists, usernames.
import '../core/i18n.dart';

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
  'ľ': 'l', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ť': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// Lowercase, without accents, trimmed. "Hélène " → "helene"
String normalizeText(String s) {
  final lower = s.toLowerCase().trim();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    // combining diacritical marks (U+0300–U+036F)
    if (r >= 0x300 && r <= 0x36F) continue;
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Substring match, ignoring case and accents. Empty query matches everything.
bool matchesQuery(String? haystack, String query) {
  if (query.trim().isEmpty) return true;
  if (haystack == null) return false;
  return normalizeText(haystack).contains(normalizeText(query));
}

/// True if any of the fields matches the query.
bool matchesAny(Iterable<String?> fields, String query) =>
    query.trim().isEmpty || fields.any((f) => matchesQuery(f, query));

int compareNames(String a, String b) {
  final c = normalizeText(a).compareTo(normalizeText(b));
  return c != 0 ? c : a.compareTo(b);
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Marie Dupont" → "MD", "Marie" → "MA"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Stable index (0..9) derived from the name, for avatar colors.
int colorIndexFor(String name) {
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return h % 10;
}

/// "Marie, Paul et Léa" / "Marie, Paul, Léa et 2 autres"
String joinNames(List<String> names, {int max = 3}) {
  final list = names.where((n) => n.isNotEmpty).toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return list.first;
  if (list.length <= max) return '${list.sublist(0, list.length - 1).join(', ')} ${tr.and} ${list.last}';
  return '${list.take(max).join(', ')} ${tr.andOthers(list.length - max)}';
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
bool isValidEmail(String s) => _emailRe.hasMatch(s.trim());

/* ------------------------------------------------------------------ */
/*  Usernames                                                          */
/* ------------------------------------------------------------------ */

const usernameMin = 3;
const usernameMax = 20;
final usernameRe = RegExp(r'^[a-z0-9][a-z0-9_.]{2,19}$');
String get usernameHint => tr.usernameHint;

/// Cleans input while typing: no "@", accents, spaces or forbidden characters.
String normalizeUsername(String raw) {
  final s = normalizeText(raw).replaceAll(RegExp(r'[^a-z0-9_.]'), '');
  return s.length > usernameMax ? s.substring(0, usernameMax) : s;
}

/// Error message if the format is invalid, else null.
String? usernameFormatError(String value) {
  if (value.length < usernameMin) return tr.usernameTooShort(usernameMin);
  if (!RegExp(r'^[a-z0-9]').hasMatch(value)) return tr.usernameBadStart;
  if (!usernameRe.hasMatch(value)) return usernameHint;
  return null;
}

/// "@andrea" (or "" when missing)
String handle(String? username) => username == null || username.isEmpty ? '' : '@$username';

/// Initial suggestion from a first name or an email.
String suggestUsername(String? source) {
  final base = normalizeUsername((source ?? '').split('@').first.replaceAll(RegExp(r'\s+'), '.'));
  return base.replaceFirst(RegExp(r'^[_.]+'), '');
}
