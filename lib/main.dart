import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'contact_list_screen.dart';
import '/models/contact.dart';
import 'dart:io';  // Assure-toi que cette ligne est présente

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
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

  // Récupérer les 5 contacts les plus récents (Prochainement)
  List<Contact> get upcomingContacts {
    List<Contact> sortedContacts = List.from(contacts);
    sortedContacts.sort((a, b) => a.nextMeetingDate.compareTo(b.nextMeetingDate));
    return sortedContacts.take(5).toList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meet Reminder')),
      body: _currentIndex == 0
          ? UpcomingContactsPage(upcomingContacts: upcomingContacts) // Page principale
          : ContactListScreen(contacts: contacts, updateContacts: (updatedContacts) {
              setState(() {
                contacts = updatedContacts;
              });
            }),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Prochainement'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
        ],
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class UpcomingContactsPage extends StatelessWidget {
  final List<Contact> upcomingContacts;

  const UpcomingContactsPage({super.key, required this.upcomingContacts});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: upcomingContacts.length,
      itemBuilder: (context, index) {
        final contact = upcomingContacts[index];
        return ListTile(
          leading: contact.imagePath != null
              ? CircleAvatar(backgroundImage: FileImage(File(contact.imagePath!))) // Utilisation de File
              : const CircleAvatar(child: Icon(Icons.person)),
          title: Text(contact.name),
          subtitle: Text("Prochaine rencontre : ${contact.nextMeetingDate.toString()}"),
          onTap: () {
            // Ajouter l'action de navigation ou d'édition ici si nécessaire
          },
        );
      },
    );
  }
}