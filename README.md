# Gestion des Rencontres

Ce projet est une application Flutter permettant de gérer les rencontres avec ses amis et contacts. L'application envoie des rappels pour revoir les contacts en fonction d'une fréquence définie et permet d'ajouter des rendez-vous avec des photos.

## Fonctionnalités
- **Gestion des contacts** : Ajouter, modifier et supprimer des contacts.
- **Suivi des rendez-vous** : Ajouter des rendez-vous avec une date et une photo.
- **Rappels automatiques** : Notification pour rappeler de revoir un contact.
- **Stockage local** : Sauvegarde des données avec `SharedPreferences`.
- **Interface intuitive** : Affichage des prochains contacts à voir et des rendez-vous à venir.

## Installation
1. **Cloner le projet**
   ```sh
   git clone https://github.com/votre-utilisateur/gestion-rencontres.git
   cd gestion-rencontres
   ```
2. **Installer les dépendances**
   ```sh
   flutter pub get
   ```
3. **Lancer l'application**
   ```sh
   flutter run
   ```

## Structure du projet
```
lib/
│── main.dart               # Point d'entrée de l'application
├── contacts_page.dart      # Liste des contacts
├── contact_details_page.dart  # Détails d'un contact
│── models/
│   ├── contact.dart        # Modèle de contact
│   ├── rdv.dart            # Modèle de rendez-vous
│── widgets/
│   ├── contact_item.dart   # Widget d'affichage d'un contact
│   ├── rdv_item.dart       # Widget d'affichage d'un rendez-vous
│── utils/
│   ├── storage.dart        # Gestion du stockage local
```

## Technologies utilisées
- **Flutter** (Dart)
- **SharedPreferences** (Stockage local)
- **Image Picker** (Gestion des images)



## Auteur
🚀 **Cocsleboss**

