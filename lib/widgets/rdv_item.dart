import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/rdv.dart';

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
