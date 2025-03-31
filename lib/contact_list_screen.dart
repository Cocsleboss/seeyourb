import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '/models/contact.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ContactListScreen extends StatefulWidget {
  final List<Contact> contacts;
  final Function(List<Contact>) updateContacts;

  const ContactListScreen({super.key, required this.contacts, required this.updateContacts});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  // Charger les contacts depuis SharedPreferences
  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('contacts');

    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      setState(() {
        contacts = decoded.map((c) => Contact.fromJson(c)).toList();
      });
    }
  }

  int convertToDays(int value, String unit) {
    switch (unit) {
      case "semaines":
        return value * 7;
      case "mois":
        return value * 30;
      case "années":
        return value * 365;
      default:
        return value;
    }
  }

  // Sauvegarder les contacts
  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String contactsJson = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString('contacts', contactsJson);
  }

  Future<String?> pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      return image.path;
    }
    return null;
}

String formatTimeRemaining(DateTime nextMeeting) {
  Duration diff = nextMeeting.difference(DateTime.now());

  if (diff.inDays >= 730) {
    return "Dans ${diff.inDays ~/ 365} ans";
  } else if (diff.inDays >= 30) {
    return "Dans ${diff.inDays ~/ 30} mois";
  } else if (diff.inDays >= 7) {
    return "Dans ${diff.inDays ~/ 7} semaines";
  } else {
    return "Dans ${diff.inDays} jours";
  }
}

  // Ajouter un contact
  void addContact(Contact contact) {
    setState(() {
      contacts.add(contact);
      widget.contacts.add(contact);
      widget.updateContacts(widget.contacts);
    });
    saveContacts();
  }

  // Mettre à jour la dernière rencontre
  void updateNextMeetingDate(int index) {
    setState(() {
      contacts[index].updateNextMeetingDate();
    });
    saveContacts();
  }

  // Boîte de dialogue pour ajouter un contact
  void showAddContactDialog() {
    String name = "";
    int frequencyValue = 1;
    String frequencyUnit = "jours"; // Valeur par défaut
    String? imagePath;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ajouter un contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Nom"),
                onChanged: (value) => name = value,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: "Fréquence"),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        frequencyValue = int.tryParse(value) ?? 1;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      value: frequencyUnit,
                      items: ["jours", "semaines", "mois", "années"]
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          frequencyUnit = value;
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  String? pickedPath = await pickImage();
                  if (pickedPath != null) {
                    setState(() {
                      imagePath = pickedPath;
                    });
                  }
                },
                child: const Text("Ajouter une photo"),
              ),
              if (imagePath != null)
                Image.file(File(imagePath!), height: 100),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  int days = convertToDays(frequencyValue, frequencyUnit);
                  addContact(Contact(
                    name: name,
                    lastMet: DateTime.now(),
                    frequencyInDays: days,
                    imagePath: imagePath,
                  ));
                  Navigator.pop(context);
                }
              },
              child: const Text("Ajouter"),
            ),
          ],
        );
      },
    );
  }


  void showEditFrequencyDialog(Contact contact) {
    int frequencyValue = contact.frequencyInDays;
    String frequencyUnit = "jours"; // Valeur par défaut

    // Détecter l'unité actuelle
    if (contact.frequencyInDays % 365 == 0) {
      frequencyValue = contact.frequencyInDays ~/ 365;
      frequencyUnit = "années";
    } else if (contact.frequencyInDays % 30 == 0) {
      frequencyValue = contact.frequencyInDays ~/ 30;
      frequencyUnit = "mois";
    } else if (contact.frequencyInDays % 7 == 0) {
      frequencyValue = contact.frequencyInDays ~/ 7;
      frequencyUnit = "semaines";
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Modifier la fréquence"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: "Fréquence"),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: frequencyValue.toString()),
                      onChanged: (value) {
                        frequencyValue = int.tryParse(value) ?? 1;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      value: frequencyUnit,
                      items: ["jours", "semaines", "mois", "années"]
                          .map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            frequencyUnit = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  contact.frequencyInDays = convertToDays(frequencyValue, frequencyUnit);
                });
                Navigator.pop(context);
              },
              child: const Text("Modifier"),
            ),
          ],
        );
      },
    );
  }
    
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Liste de Contacts")),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          
          return Dismissible(
            key: Key(contact.name), // Clé unique pour l'animation
            direction: DismissDirection.endToStart, // Swipe uniquement de droite à gauche
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              setState(() {
                contacts.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${contact.name} supprimé")),
              );
            },
            child: ListTile(
              leading: contact.imagePath != null
                  ? CircleAvatar(backgroundImage: FileImage(File(contact.imagePath!)))
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(contact.name),
              subtitle: Text(formatTimeRemaining(contact.nextMeetingDate)),
              onTap: () {
                showEditFrequencyDialog(contact);
              },
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: showAddContactDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}