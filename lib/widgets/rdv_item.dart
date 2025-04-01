import 'package:flutter/material.dart';
import '../models/rdv.dart';

class RdvItem extends StatelessWidget {
  final Rdv rdv;

  const RdvItem({Key? key, required this.rdv}) : super(key: key);

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.calendar_today),
      title: Text(rdv.contact.name),
      subtitle: Text(_formatDate(rdv.date)),
    );
  }
}
