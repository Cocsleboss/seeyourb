import 'contact.dart';

class Rdv {
  List<Contact> contacts;
  DateTime date;
  String? photoPath;
  bool isDone; // Nouveau champ

  Rdv({
    required this.contacts,
    required this.date,
    this.photoPath,
    this.isDone = false, // Par défaut, le RDV n'est pas fait
  });

  Map<String, dynamic> toJson() {
    return {
      'contacts': contacts.map((c) => c.toJson()).toList(),
      'date': date.toIso8601String(),
      'photoPath': photoPath,
      'isDone': isDone,
    };
  }

  factory Rdv.fromJson(Map<String, dynamic> json) {
    List<dynamic> contactJsonList = json['contacts'];
    List<Contact> contacts =
        contactJsonList.map((c) => Contact.fromJson(c)).toList();
    return Rdv(
      contacts: contacts,
      date: DateTime.parse(json['date']),
      photoPath: json['photoPath'],
      isDone: json['isDone'] ?? false, // Si non défini, false
    );
  }
}
