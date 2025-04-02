import 'package:flutter/material.dart';
import 'contacts_page.dart';
import 'models/contact.dart';
import 'models/rdv.dart';
import 'widgets/contact_item.dart';
import 'widgets/rdv_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'utils/rdv_creator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigation App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  List<Contact> _contacts = [];
  List<Rdv> _rdvs = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? contactList = prefs.getStringList('contacts');
    List<String>? rdvList = prefs.getStringList('rdvs');
    
    if (contactList != null) {
      setState(() {
        _contacts = contactList.map((c) => Contact.fromJson(json.decode(c))).toList();
        _contacts.sort((a, b) => a.nextMeetingDate.compareTo(b.nextMeetingDate));
      });
    }
    
    if (rdvList != null) {
      setState(() {
        _rdvs = rdvList.map((r) => Rdv.fromJson(json.decode(r))).toList();
      });
    }
  }
  
  void _updateState() {
    setState(() {});
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  Widget _buildHomePage() {
    return Scaffold(
      appBar: AppBar(title: Text("SeeYourB")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Prochains contacts à voir", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Column(
              children: _contacts.take(5).map((contact) => ContactItem(
                contact: contact,
                onUpdate: () { setState(() {}); }
              )).toList(),
            ),
            SizedBox(height: 20),
            Text("Tous les RDVs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            // Bouton pour ajouter un RDV
            ElevatedButton(
              onPressed: () => _showAddRdvDialogMain(context),
              child: Text("Ajouter un RDV"),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: _rdvs.map((rdv) => RdvItem(rdv: rdv, onUpdate: () { setState(() {}); })).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  final List<Widget> _pages = [
    // Cette liste sera remplie dans build
    Container(),
    ContactsPage(),
  ];
  
  Future<void> _showAddRdvDialogMain(BuildContext context) async {
    await showAddRdvDialog(context, _contacts, (Rdv newRdv) {
      // Mettez à jour votre liste de RDVs après l'ajout
      setState(() {
        _rdvs.add(newRdv);
      });
    });
  }

  Future<void> _saveNewRdv(Rdv newRdv) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? rdvList = prefs.getStringList('rdvs');
    rdvList = rdvList ?? [];
    rdvList.add(json.encode(newRdv.toJson()));
    await prefs.setStringList('rdvs', rdvList);
    // Recharge les RDVs pour mettre à jour la liste affichée
    _loadData();
  }
  
  @override
  Widget build(BuildContext context) {
    _pages[0] = _buildHomePage();
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}


