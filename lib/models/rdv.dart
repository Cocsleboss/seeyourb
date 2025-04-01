import 'contact.dart';

class Rdv {
  final Contact contact;
  DateTime date;
  String? photoPath;

  Rdv({
    required this.contact,
    required this.date,
    this.photoPath,
  });

  // Conversion en JSON
  Map<String, dynamic> toJson() {
    return {
      'contact': contact.toJson(),
      'date': date.toIso8601String(),
      'photoPath': photoPath,
    };
  }

  // Conversion depuis JSON
  factory Rdv.fromJson(Map<String, dynamic> json) {
    return Rdv(
      contact: Contact.fromJson(json['contact']),
      date: DateTime.parse(json['date']),
      photoPath: json['photoPath'],
    );
  }
}
