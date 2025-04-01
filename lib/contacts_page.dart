import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/models/contact.dart';
import '/widgets/contact_item.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? contactList = prefs.getStringList('contacts');
    if (contactList != null) {
      setState(() {
        contacts = contactList.map((contactJson) {
          final Map<String, dynamic> jsonMap = json.decode(contactJson);
          return Contact.fromJson(jsonMap);
        }).toList();
      });
    }
  }

  Future<void> saveContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> contactList = contacts.map((contact) => json.encode(contact.toJson())).toList();
    await prefs.setStringList('contacts', contactList);
  }

  void addContact(Contact contact) {
    setState(() {
      contacts.add(contact);
    });
    saveContacts();
  }

  Future<void> _showAddContactDialog() async {
  String name = "";
  int frequency = 1;
  String selectedUnit = "jours";
  String? imagePath;

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Ajouter un contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: "Nom"),
              onChanged: (value) {
                name = value;
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: "Fréquence"),
              keyboardType: TextInputType.number,
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
                  selectedUnit = value;
                }
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
            child: Text("Ajouter"),
            onPressed: () {
              if (name.isNotEmpty && frequency > 0) {
                int frequencyInDays = _convertToDays(frequency, selectedUnit);
                addContact(Contact(
                  name: name,
                  lastMet: DateTime.now(),
                  frequencyInDays: frequencyInDays,
                  imagePath: imagePath,
                ));
                Navigator.of(context).pop();
              }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Contacts"),
      ),

      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return Dismissible(
            key: Key(contact.name), // Utiliser un identifiant unique
            direction: DismissDirection.endToStart, // Balayage vers la gauche
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              setState(() {
                contacts.removeAt(index);
              });
              saveContacts(); // Sauvegarde après suppression
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${contact.name} supprimé")),
              );
            },
            child: ContactItem(
              contact: contact,
              onUpdate: saveContacts,
            ),
          );
        },
      ),





      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
