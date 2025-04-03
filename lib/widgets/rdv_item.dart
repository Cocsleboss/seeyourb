import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rdv.dart';
import '../models/contact.dart';

class RdvItem extends StatefulWidget {
  final Rdv rdv;
  final VoidCallback onUpdate;
  final VoidCallback onSave;

  const RdvItem({
    Key? key,
    required this.rdv,
    required this.onUpdate,
    required this.onSave,
  }) : super(key: key);

  @override
  _RdvItemState createState() => _RdvItemState();
}

class _RdvItemState extends State<RdvItem> {
  Future<void> _showEditDialog(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text("Modifier la date et l'heure"),
                onTap: () {
                  Navigator.pop(context);
                  _selectDate(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text("Ajouter une photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.group),
                title: Text("Modifier les contacts"),
                onTap: () {
                  Navigator.pop(context);
                  _editContacts(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.rdv.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.rdv.date),
      );
      if (pickedTime != null) {
        setState(() {
          widget.rdv.date = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
        widget.onUpdate();
        widget.onSave();
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        widget.rdv.photoPath = pickedFile.path;
      });
      widget.onUpdate();
      widget.onSave();
    }
  }

  /// Permet d'éditer la liste des contacts associés au RDV.
  Future<void> _editContacts(BuildContext context) async {
    // Charger tous les contacts depuis SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? contactList = prefs.getStringList('contacts');
    List<Contact> allContacts = [];
    if (contactList != null) {
      allContacts = contactList
          .where((c) => c.isNotEmpty)
          .map((c) {
            try {
              return Contact.fromJson(json.decode(c));
            } catch (e) {
              print("Erreur de parsing JSON (contact) : $e");
              return null;
            }
          })
          .where((c) => c != null)
          .cast<Contact>()
          .toList();
    }

    // Créer une copie de la liste actuelle des contacts du RDV
    List<Contact> editedContacts = List.from(widget.rdv.contacts);
    TextEditingController textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("Modifier les contacts"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<Contact>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Contact>.empty();
                      }
                      return allContacts.where((Contact option) {
                        return option.name.toLowerCase().contains(
                            textEditingValue.text.toLowerCase());
                      });
                    },
                    displayStringForOption: (Contact option) => option.name,
                    onSelected: (Contact selection) {
                      setStateDialog(() {
                        if (!editedContacts.contains(selection)) {
                          editedContacts.add(selection);
                        }
                      });
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController controller,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Rechercher un contact',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 10),
                  // Affichage des contacts sélectionnés sous forme de Chips
                  Wrap(
                    spacing: 8,
                    children: editedContacts
                        .map((c) => Chip(
                              label: Text(c.name),
                              onDeleted: () {
                                setStateDialog(() {
                                  editedContacts.remove(c);
                                });
                              },
                            ))
                        .toList(),
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
                child: Text("Enregistrer"),
                onPressed: () {
                  setState(() {
                    widget.rdv.contacts = editedContacts;
                  });
                  widget.onUpdate();
                  widget.onSave();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${widget.rdv.date.day}/${widget.rdv.date.month}/${widget.rdv.date.year} ${widget.rdv.date.hour}:${widget.rdv.date.minute.toString().padLeft(2, '0')}";
    // Concatène les noms de tous les contacts séparés par des virgules.
    String contactsNames =
        widget.rdv.contacts.map((c) => c.name).join(", ");
    
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          leading: Icon(Icons.calendar_today, color: Colors.blue),
          title: Text(contactsNames),
          subtitle: Text(formattedDate),
          trailing: widget.rdv.photoPath != null
              ? Image.file(File(widget.rdv.photoPath!), width: 50, height: 50, fit: BoxFit.cover)
              : null,
        ),
      ),
    );
  }
}
