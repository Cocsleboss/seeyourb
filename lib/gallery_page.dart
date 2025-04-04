import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rdv.dart';
import '../models/contact.dart';
import 'photo_viewer_page.dart';
import '/models/PhotoRdv.dart';


class RdvGalleryPage extends StatefulWidget {
  final Contact contact;

  const RdvGalleryPage({Key? key, required this.contact}) : super(key: key);

  @override
  _RdvGalleryPageState createState() => _RdvGalleryPageState();
}

class _RdvGalleryPageState extends State<RdvGalleryPage> {
  List<PhotoRdv> photoRdvs = [];

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? rdvList = prefs.getStringList('rdvs');
    List<Rdv> rdvs = [];
    if (rdvList != null) {
      rdvs = rdvList.map((r) {
        try {
          return Rdv.fromJson(json.decode(r));
        } catch (e) {
          print("Erreur de parsing RDV: $e");
          return null;
        }
      }).where((rdv) => rdv != null).cast<Rdv>().toList();
    }
    // Filtrer les RDVs qui contiennent le contact et qui ont une photo
    List<PhotoRdv> photos = [];
    for (var rdv in rdvs) {
      if (rdv.photoPath != null) {
        bool containsContact = rdv.contacts.any((c) =>
            c.name.toLowerCase() == widget.contact.name.toLowerCase());
        if (containsContact) {
          photos.add(PhotoRdv(photoPath: rdv.photoPath!, date: rdv.date));
        }
      }
    }
    setState(() {
      photoRdvs = photos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Galerie de ${widget.contact.name}"),
      ),
      body: photoRdvs.isEmpty
          ? Center(child: Text("Aucune photo disponible"))
          : GridView.builder(
              padding: EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: photoRdvs.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Naviguer vers la page de visionnage en plein écran
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerPage(
                          photoRdvs: photoRdvs,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Image.file(
                    File(photoRdvs[index].photoPath),
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
    );
  }
}
