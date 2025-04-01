import 'package:flutter/material.dart';
import '../models/contact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../contact_details_page.dart';

class ContactItem extends StatefulWidget {
  final Contact contact;
  final VoidCallback onUpdate; // Callback pour notifier la mise à jour

  const ContactItem({Key? key, required this.contact, required this.onUpdate}) : super(key: key);

  @override
  _ContactItemState createState() => _ContactItemState();
}

class _ContactItemState extends State<ContactItem> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remainingDays = widget.contact.nextMeetingDate.difference(now).inDays;
    final formattedTime = _formatRemainingTime(remainingDays);

    return ListTile(
      leading: widget.contact.imagePath != null
          ? CircleAvatar(
              backgroundImage: FileImage(File(widget.contact.imagePath!)), // Correction ici
            )
          : CircleAvatar(child: Text(widget.contact.name[0])),
      title: Text(widget.contact.name),
      subtitle: Text("À revoir $formattedTime"),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailsPage(
              contact: widget.contact,
              onUpdate: widget.onUpdate,
            ),
          ),
        ).then((_) {
          // Rafraîchit la liste des contacts à votre retour
          widget.onUpdate();
        });
      },

    );
  }

  String _formatRemainingTime(int days) {
    if (days >= 365 * 2) {
      return "dans ${days ~/ 365} ans";
    } else if (days >= 30) {
      return "dans ${days ~/ 30} mois";
    } else if (days >= 7) {
      return "dans ${days ~/ 7} semaines";
    } else {
      return "dans $days jours";
    }
  }
}
