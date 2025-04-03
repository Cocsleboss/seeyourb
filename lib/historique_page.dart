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
import 'historique_page.dart';
import 'main.dart';

class HistoriquePage extends StatelessWidget {
  final List<Rdv> rdvs;

  HistoriquePage({required this.rdvs});

  @override
  Widget build(BuildContext context) {
    // Filtrer les RDVs "done" (déjà passés)
    final doneRdvs = rdvs.where((rdv) => rdv.isDone).toList();

    return Scaffold(
      appBar: AppBar(title: Text("Historique des RDVs")),
      body: doneRdvs.isEmpty
          ? Center(child: Text("Aucun RDV terminé."))
          : ListView.builder(
            itemCount: doneRdvs.length,
            itemBuilder: (context, index) {
              final rdv = doneRdvs[index];
              return RdvItem(
                rdv: rdv,
                onUpdate: () {}, // Pas besoin de mettre à jour ici
                onSave: () {}, // Historique, donc pas de sauvegarde nécessaire
                onDelete: () {
                  // Gérer la suppression si besoin
                },
              );
            },
          ),
    );
  }
}
