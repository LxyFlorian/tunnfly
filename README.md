# Tunnfly

Application de messagerie instantanée sécurisée avec chiffrement de bout en bout (E2E), développée en Flutter.

## Fonctionnalités

- **Chiffrement E2E** — chaque message est chiffré localement avant d'être transmis au serveur
- **Authentification** — inscription, connexion et gestion de session via Supabase Auth
- **Conversations** — messagerie en temps réel entre utilisateurs
- **Stockage sécurisé** — les clés privées ne quittent jamais l'appareil
- **Multi-plateforme** — Android, iOS, Web, macOS, Linux, Windows

## Stack technique

| Couche | Technologie |
|---|---|
| Framework | Flutter / Dart |
| Backend & BDD | Supabase (PostgreSQL) |
| État | Flutter Riverpod |
| Cryptographie | X25519 (échange de clés) + AES-256-GCM (chiffrement) |
| Stockage local | flutter_secure_storage |

## Architecture de sécurité

1. À l'inscription, une paire de clés X25519 est générée sur l'appareil
2. La clé publique est stockée dans Supabase ; la clé privée reste dans le stockage sécurisé local
3. Lors d'une conversation, un secret partagé est dérivé via Diffie-Hellman
4. Chaque message est chiffré avec AES-256-GCM avant envoi et déchiffré à la réception
5. Le serveur ne voit jamais le contenu des messages en clair

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.0
- Un projet [Supabase](https://supabase.com) configuré

## Installation

```bash
git clone https://github.com/LxyFlorian/tunnfly.git
cd tunnfly
flutter pub get
```

Créez un fichier `.env` ou configurez vos variables Supabase dans `lib/main.dart` :

```dart
await Supabase.initialize(
  url: 'VOTRE_SUPABASE_URL',
  anonKey: 'VOTRE_SUPABASE_ANON_KEY',
);
```

## Lancer l'application

```bash
flutter run
```

## Structure du projet

```
lib/
├── main.dart               # Point d'entrée, initialisation Supabase
├── app.dart                # Widget racine et routage
├── core/
│   └── crypto/             # Logique de chiffrement et gestion des clés
└── features/
    ├── auth/               # Authentification (écrans, providers, modèles)
    └── chat/               # Messagerie (conversations, messages)
```

## Licence

MIT
