

import 'package:flutter/material.dart';
import 'dart:io';
import '/models/contact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ContactDetailsPage extends StatefulWidget {
  final Contact contact;
  final VoidCallback onUpdate;

  const ContactDetailsPage({Key? key, required this.contact, required this.onUpdate}) : super(key: key);

  @override
  _ContactDetailsPageState createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remainingDays = widget.contact.nextMeetingDate.difference(now).inDays;
    final formattedTime = _formatRemainingTime(remainingDays);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contact.name),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _showEditDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.contact.imagePath != null
                  ? FileImage(File(widget.contact.imagePath!))
                  : null,
              child: widget.contact.imagePath == null
                  ? Text(widget.contact.name[0], style: TextStyle(fontSize: 40))
                  : null,
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Dernière rencontre : ${_formatDate(widget.contact.lastMet)}"),
                SizedBox(height: 8),
                Text("Quand est-ce qu'on doit le revoir : $formattedTime"),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {}, // Ajouter un RDV (non implémenté)
              child: Text("Ajouter un RDV"),
            ),
            ElevatedButton(
              onPressed: () => _showEditDialog2(context),
              child: Text("Modifier la fréquence"),
            ),
            ElevatedButton(
              onPressed: () {}, // Voir galerie des RDV (non implémenté)
              child: Text("Voir la galerie des RDV"),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRemainingTime(int days) {
    if (days >= 365 * 2) {
      return "dans ${days ~/ 365} ans";
    } else if (days >= 30) {
      return "dans ${days ~/ 30} mois";
    } else if (days >= 7) {
      return "dans ${days ~/ 7} semaines";
    } else {
      return "dans $days jours";
    }
  }

    String _formatDate(DateTime date) {
      return "${date.day}/${date.month}/${date.year}";
    }

    Future<void> _showEditDialog2(BuildContext context) async {
      String name = widget.contact.name;
      int frequency = widget.contact.frequencyInDays;
      String selectedUnit = "jours";

      if (frequency % 365 == 0) {
        selectedUnit = "années";
        frequency ~/= 365;
      } else if (frequency % 30 == 0) {
        selectedUnit = "mois";
        frequency ~/= 30;
      } else if (frequency % 7 == 0) {
        selectedUnit = "semaines";
        frequency ~/= 7;
      }

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Modifier le contact"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: "Nom"),
                  controller: TextEditingController(text: name),
                  onChanged: (value) {
                    name = value;
                  },
                ),
                TextField(
                  decoration: InputDecoration(labelText: "Fréquence"),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: frequency.toString()),
                  onChanged: (value) {
                    frequency = int.tryParse(value) ?? 1;
                  },
                ),
                DropdownButton<String>(
                  value: selectedUnit,
                  items: ["jours", "semaines", "mois", "années"].map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedUnit = value;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text("Annuler"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Enregistrer"),
                onPressed: () async {
                  int frequencyInDays = _convertToDays(frequency, selectedUnit);
                  widget.contact.name = name;
                  widget.contact.frequencyInDays = frequencyInDays;
                  widget.contact.lastMet = DateTime.now();

                  await _saveUpdatedContact();
                  widget.onUpdate();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    int _convertToDays(int value, String unit) {
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

  Future<void> _showEditDialog(BuildContext context) async {
    String name = widget.contact.name;
    String? imagePath = widget.contact.imagePath;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Modifier le contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: "Nom"),
                controller: TextEditingController(text: name),
                onChanged: (value) {
                  name = value;
                },
              ),
              SizedBox(height: 10),
              imagePath != null
                  ? Image.file(File(imagePath!), height: 100)
                  : Container(),
              ElevatedButton(
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    imagePath = pickedFile.path;
                    setState(() {}); // Actualise l'aperçu de l'image
                  }
                },
                child: Text("Choisir une image"),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Annuler"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Enregistrer"),
              onPressed: () async {
                widget.contact.name = name;
                widget.contact.imagePath = imagePath;
                await _saveUpdatedContact();
                widget.onUpdate();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveUpdatedContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? contactList = prefs.getStringList('contacts');
    if (contactList != null) {
      List<Contact> contacts = contactList.map((contactJson) {
        return Contact.fromJson(json.decode(contactJson));
      }).toList();

      int index = contacts.indexWhere((c) => c.name == widget.contact.name);
      if (index != -1) {
        contacts[index] = widget.contact;
        List<String> updatedList = contacts.map((c) => json.encode(c.toJson())).toList();
        await prefs.setStringList('contacts', updatedList);
      }
    }
  }
}
