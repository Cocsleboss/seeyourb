import 'package:flutter/material.dart';
import 'contact_list_screen.dart';
import 'models/contact.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Contact> contacts = [];

  void updateContacts(List<Contact> newContacts) {
    setState(() {
      contacts = newContacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meet Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MainPage(contacts: contacts, updateContacts: updateContacts),
    );
  }
}

class MainPage extends StatefulWidget {
  final List<Contact> contacts;
  final Function(List<Contact>) updateContacts;

  const MainPage({super.key, required this.contacts, required this.updateContacts});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Contact> upcomingContacts = widget.contacts
        .where((contact) => contact.nextMeetingDate.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.nextMeetingDate.compareTo(b.nextMeetingDate));

    upcomingContacts = upcomingContacts.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Meet Reminder')),
      body: _currentIndex == 0
          ? HomePage(upcomingContacts: upcomingContacts)
          : ContactListScreen(contacts: widget.contacts, updateContacts: widget.updateContacts),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
        ],
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Contact> upcomingContacts;

  const HomePage({super.key, required this.upcomingContacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Prochaines rencontres', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: upcomingContacts.length,
            itemBuilder: (context, index) {
              final contact = upcomingContacts[index];
              return ListTile(
                leading: contact.imagePath != null
                    ? CircleAvatar(backgroundImage: AssetImage(contact.imagePath!))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact.name),
                subtitle: Text('Dans ${_timeUntil(contact.nextMeetingDate)}'),
              );
            },
          ),
        ),
      ],
    );
  }

  String _timeUntil(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays >= 730) {
      return '${(difference.inDays / 365).floor()} ans';
    } else if (difference.inDays >= 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays >= 7) {
      return '${(difference.inDays / 7).floor()} semaines';
    } else {
      return '${difference.inDays} jours';
    }
  }
}