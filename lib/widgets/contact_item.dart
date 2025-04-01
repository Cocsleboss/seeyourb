import 'package:flutter/material.dart';
import '../models/contact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../contact_details_page.dart';

class ContactItem extends StatefulWidget {
  final Contact contact;
  final VoidCallback onUpdate; // Callback pour notifier la mise à jour

  const ContactItem({Key? key, required this.contact, required this.onUpdate}) : super(key: key);

  @override
  _ContactItemState createState() => _ContactItemState();
}

class _ContactItemState extends State<ContactItem> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remainingDays = widget.contact.nextMeetingDate.difference(now).inDays;
    final formattedTime = _formatRemainingTime(remainingDays);

    return ListTile(
      leading: widget.contact.imagePath != null
          ? CircleAvatar(
              backgroundImage: FileImage(File(widget.contact.imagePath!)), // Correction ici
            )
          : CircleAvatar(child: Text(widget.contact.name[0])),
      title: Text(widget.contact.name),
      subtitle: Text("À revoir $formattedTime"),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailsPage(
              contact: widget.contact,
              onUpdate: widget.onUpdate,
            ),
          ),
        ).then((_) {
          // Rafraîchit la liste des contacts à votre retour
          widget.onUpdate();
        });
      },

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

  Future<void> _showEditDialog(BuildContext context) async {
    String name = widget.contact.name;
    int frequency = widget.contact.frequencyInDays;
    String selectedUnit = "jours";

    // Déterminer l'unité actuelle
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
                widget.onUpdate(); // Met à jour l'affichage
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
        return value; // Jours par défaut
    }
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
