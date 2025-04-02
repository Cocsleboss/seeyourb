import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/models/contact.dart';
import '/widgets/contact_item.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'utils/contact_creator.dart'; // Import du manager

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> contacts = [];
  String searchQuery = "";

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

  @override
  Widget build(BuildContext context) {
    // Filtrer les contacts en fonction de la recherche
    List<Contact> filteredContacts = contacts.where((contact) {
      return contact.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Contacts"),
      ),
      body: Column(
        children: [
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Rechercher un contact",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          // Liste des contacts filtrés
          Expanded(
            child: ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                return Dismissible(
                  key: Key(contact.name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    setState(() {
                      contacts.removeWhere((c) => c.name == contact.name);
                    });
                    saveContacts();
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddContactDialog(context, (Contact newContact) {
            addContact(newContact);
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
