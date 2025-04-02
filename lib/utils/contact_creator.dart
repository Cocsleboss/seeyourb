import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/contact.dart';

/// Affiche un dialogue pour ajouter un contact et renvoie le nouveau contact via le callback [onContactAdded].
Future<void> showAddContactDialog(BuildContext context, Function(Contact) onContactAdded) async {
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
                Contact newContact = Contact(
                  name: name,
                  lastMet: DateTime.now(),
                  frequencyInDays: frequencyInDays,
                  imagePath: imagePath,
                );
                onContactAdded(newContact);
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
