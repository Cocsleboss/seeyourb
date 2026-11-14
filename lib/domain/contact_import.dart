// Phone-book import: cleaning and de-duplication (§4.8).
import 'text.dart';

class ImportedContact {
  ImportedContact({required this.key, required this.name, this.phone, this.email, this.birthday, this.notes});
  final String key;
  final String name;
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? notes;
}

String? cleanPhone(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().replaceFirst(RegExp(r'^tel:', caseSensitive: false), '');
  s = s.split(';').first.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (!RegExp(r'\d').hasMatch(s)) return null;
  return s.length > 40 ? s.substring(0, 40) : s;
}

String? cleanEmail(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().replaceFirst(RegExp(r'^mailto:', caseSensitive: false), '').toLowerCase();
  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(s)) return null;
  return s.length > 120 ? s.substring(0, 120) : s;
}

/// Phone comparison key: digits only, last 9 (06 12… ≡ +33 6 12…).
String? phoneKey(String? phone) {
  if (phone == null) return null;
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length < 6) return null;
  return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
}

String nameKey(String name) => normalizeText(name).replaceAll(RegExp(r'\s+'), ' ');

String? emailKey(String? email) {
  final e = email?.trim().toLowerCase();
  return e == null || e.isEmpty ? null : e;
}

class DedupeResult {
  DedupeResult(this.fresh, this.alreadyThere, this.duplicates);

  /// New people to propose.
  final List<ImportedContact> fresh;

  /// Already present in SeeU (same name, phone or email).
  final int alreadyThere;

  /// Duplicates inside the selection itself.
  final int duplicates;
}

/// [existing] are (name, phone, email) of contacts already in SeeU.
DedupeResult dedupeImported(List<ImportedContact> list, List<({String name, String? phone, String? email})> existing) {
  final appNames = existing.map((c) => nameKey(c.name)).toSet();
  final appPhones = existing.map((c) => phoneKey(c.phone)).whereType<String>().toSet();
  final appEmails = existing.map((c) => emailKey(c.email)).whereType<String>().toSet();
  final seenNames = <String>{}, seenPhones = <String>{}, seenEmails = <String>{};
  final fresh = <ImportedContact>[];
  var already = 0, dups = 0;

  for (final c in list) {
    final nk = nameKey(c.name);
    final pk = phoneKey(c.phone);
    final ek = emailKey(c.email);
    if (appNames.contains(nk) || (pk != null && appPhones.contains(pk)) || (ek != null && appEmails.contains(ek))) {
      already++;
      continue;
    }
    if (seenNames.contains(nk) || (pk != null && seenPhones.contains(pk)) || (ek != null && seenEmails.contains(ek))) {
      dups++;
      continue;
    }
    seenNames.add(nk);
    if (pk != null) seenPhones.add(pk);
    if (ek != null) seenEmails.add(ek);
    fresh.add(c);
  }
  return DedupeResult(fresh, already, dups);
}
