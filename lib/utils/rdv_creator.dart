import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/rdv.dart';
import '../models/contact.dart';

/// Affiche un dialogue pour ajouter un RDV.
/// [contacts] : la liste des contacts disponibles.
/// [onRdvAdded] : callback appelé avec le nouveau RDV une fois créé.
Future<void> showAddRdvDialog(BuildContext context, List<Contact> contacts, Function(Rdv) onRdvAdded) async {
  Contact? selectedContact = contacts.isNotEmpty ? contacts.first : null;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          String formattedDate = "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}";
          String formattedTime = selectedTime.format(context);
          return AlertDialog(
            title: Text("Ajouter un RDV"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Choix du contact avec suggestions Autocomplete
                  Autocomplete<Contact>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<Contact>.empty();
                      }
                      return contacts.where((Contact option) {
                        return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (Contact option) => option.name,
                    onSelected: (Contact selection) {
                      setState(() {
                        selectedContact = selection;
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController textEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      // Si un contact est déjà sélectionné, on affiche son nom
                      if (selectedContact != null) {
                        textEditingController.text = selectedContact!.name;
                      }
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Contact',
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 10),
                  // Sélection de la date
                  Row(
                    children: [
                      Text("Date : "),
                      Text(formattedDate),
                      IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  // Sélection de l'heure
                  Row(
                    children: [
                      Text("Heure : "),
                      Text(formattedTime),
                      IconButton(
                        icon: Icon(Icons.access_time),
                        onPressed: () async {
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (pickedTime != null) {
                            setState(() {
                              selectedTime = pickedTime;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
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
                onPressed: () async {
                  if (selectedContact != null) {
                    DateTime finalDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );
                    Rdv newRdv = Rdv(
                      contact: selectedContact!,
                      date: finalDateTime,
                      photoPath: null, // On ne gère plus la photo ici
                    );
                    onRdvAdded(newRdv);
                    await saveNewRdv(newRdv);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

/// Sauvegarde un nouveau RDV dans SharedPreferences.
Future<void> saveNewRdv(Rdv newRdv) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String>? rdvList = prefs.getStringList('rdvs');
  rdvList = rdvList ?? [];
  rdvList.add(json.encode(newRdv.toJson()));
  await prefs.setStringList('rdvs', rdvList);
}
