# Patch Notes

## [0.0.2] — 2026-04-09

### Nouveautés

- **Suppression de messages** : appui long sur un message pour afficher un menu contextuel avec les options Copier, Partager et Supprimer.
- **Menu contextuel animé** : apparition fluide avec effet de scale et fondu, positionné intelligemment selon la position du message et les bords de l'écran.
- **Sécurité** : ajout d'une politique RLS Supabase limitant la suppression d'un message à son expéditeur uniquement.
- **Thème Cupertino** : intégration de `CupertinoThemeData` pour un rendu cohérent de la couleur primaire sur iOS (modes clair et sombre).
- **Lu / Distribué** : indicateur visuel sur chaque message montrant s'il a été distribué ou lu par le destinataire. Les messages reçus sont automatiquement marqués comme lus à l'ouverture de la conversation ou à leur réception en temps réel.

---


## [0.0.1] — Initial release