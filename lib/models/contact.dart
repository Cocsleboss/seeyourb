class Contact {
  String name;
  DateTime lastMet;
  int frequencyInDays;
  String? imagePath;

  Contact({
    required this.name,
    required this.lastMet,
    required this.frequencyInDays,
    this.imagePath,
  });

  DateTime get nextMeetingDate => lastMet.add(Duration(days: frequencyInDays));

  void updateNextMeetingDate() {
    lastMet = DateTime.now();
  }

  // Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lastMet': lastMet.toIso8601String(),
      'frequencyInDays': frequencyInDays,
      'imagePath': imagePath, // Sauvegarde du chemin de l'image
    };
  }

  // Convertir depuis JSON
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      name: json['name'],
      lastMet: DateTime.parse(json['lastMet']),
      frequencyInDays: json['frequencyInDays'],
      imagePath: json['imagePath'],
    );
  }
}