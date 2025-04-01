import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/rdv.dart';

class RdvItem extends StatefulWidget {
  final Rdv rdv;
  final VoidCallback onUpdate;

  const RdvItem({Key? key, required this.rdv, required this.onUpdate}) : super(key: key);

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
                title: Text("Modifier la date"),
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

    if (pickedDate != null && pickedDate != widget.rdv.date) {
      setState(() {
        widget.rdv.date = pickedDate;
      });
      widget.onUpdate();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          leading: Icon(Icons.calendar_today, color: Colors.blue),
          title: Text(widget.rdv.contact.name),
          subtitle: Text("${widget.rdv.date.day}/${widget.rdv.date.month}/${widget.rdv.date.year}"),
          trailing: widget.rdv.photoPath != null
              ? Image.file(File(widget.rdv.photoPath!), width: 50, height: 50, fit: BoxFit.cover)
              : null,
        ),
      ),
    );
  }
}
