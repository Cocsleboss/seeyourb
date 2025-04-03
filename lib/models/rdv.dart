import 'contact.dart';

class Rdv {
  List<Contact> contacts; // Retirez "final" ici
  DateTime date;
  String? photoPath;

  Rdv({
    required this.contacts,
    required this.date,
    this.photoPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'contacts': contacts.map((c) => c.toJson()).toList(),
      'date': date.toIso8601String(),
      'photoPath': photoPath,
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
    );
  }
}
