# Check-list de QA manuelle — Sòti MQ

À parcourir avant toute mise en ligne importante (pas d'outillage requis : un navigateur et 2-3 comptes de test suffisent).

## Comptes et connexion

- [ ] Inscription avec e-mail + mot de passe fonctionne
- [ ] Impossible de s'inscrire sans cocher CGU et confirmation d'âge (18 ans+)
- [ ] Connexion avec un compte existant fonctionne
- [ ] "Mot de passe oublié ?" envoie un e-mail avec un lien de réinitialisation
- [ ] Le lien de réinitialisation ouvre bien l'écran "Nouveau mot de passe" (et pas l'appli normale)
- [ ] Après réinitialisation, connexion possible avec le nouveau mot de passe
- [ ] Déconnexion fonctionne

## Onboarding et profil

- [ ] Onboarding (prénom, commune, centres d'intérêt, âge/bio/photo) se termine correctement
- [ ] Impossible de continuer sans au moins 3 centres d'intérêt
- [ ] Âge < 18 ans refusé avec message clair
- [ ] Modification du profil (prénom, commune, bio, âge, centres d'intérêt) sauvegarde bien
- [ ] Upload de photo de profil fonctionne et s'affiche partout (fil, chat, profil)
- [ ] "Membre depuis [mois année]" et les compteurs de sorties s'affichent correctement

## Sorties

- [ ] Création d'une sortie classique (avec lieu) fonctionne
- [ ] Création d'une sortie "en visio" fonctionne (pas de champ lieu, lien Jitsi généré)
- [ ] Impossible de publier sans photo de profil
- [ ] Rejoindre une sortie qui a de la place fonctionne (statut "inscrit")
- [ ] Rejoindre une sortie complète met en liste d'attente (statut "liste_attente")
- [ ] Quitter une sortie libère une place et promeut automatiquement le premier de la liste d'attente
- [ ] Le bouton "Rejoindre l'appel visio" est visible uniquement sur les sorties en visio, pour l'organisateur et les inscrits confirmés

## Chat de groupe

- [ ] Les participants confirmés ("inscrit") peuvent lire et écrire dans le chat
- [ ] Les personnes en liste d'attente ne voient PAS le chat et n'ont pas de bouton pour y accéder
- [ ] Un message contenant un lien, un numéro de carte ou un IBAN est bloqué avec un message d'erreur clair
- [ ] Envoyer un message très rapidement en rafale (> 20 en moins d'une minute) déclenche le blocage anti-spam
- [ ] Le bouton d'appel vidéo dans l'en-tête du chat ouvre bien une visio Jitsi

## Signalements et modération

- [ ] Signaler une sortie fonctionne et crée bien un signalement
- [ ] Signaler un profil (ex. "Photo de profil inappropriée") fonctionne
- [ ] Un compte admin voit tous les signalements dans Profil > Modération
- [ ] Un compte non-admin ne voit PAS l'onglet Modération
- [ ] Depuis la modération : changer le statut d'un signalement (traité / classé sans suite) fonctionne
- [ ] Depuis la modération : suspendre, bannir, réactiver un compte fonctionne
- [ ] Depuis la modération : "Retirer la photo" sur un profil signalé fonctionne
- [ ] Un compte suspendu/banni ne peut plus créer de sortie, s'inscrire ni écrire de message

## Notifications push

- [ ] Le bouton "Activer les notifications" (bandeau ou Profil) déclenche la demande d'autorisation
- [ ] Une nouvelle sortie publiée déclenche une notification chez les autres membres abonnés
- [ ] Un nouveau message déclenche une notification chez les participants concernés (hors auteur)
- [ ] Cliquer sur la notification ouvre l'appli sur le bon onglet (Fil ou Messages)
- [ ] "Désactiver" les notifications depuis le profil fonctionne

## Données personnelles (RGPD)

- [ ] "Exporter mes données" télécharge un fichier JSON complet et lisible (profil, sorties, participations, messages, signalements)
- [ ] "Supprimer mon compte" supprime bien le profil, les sorties organisées, les participations et les messages, puis déconnecte

## Divers

- [ ] L'application s'installe correctement en PWA ("Ajouter à l'écran d'accueil" sur iOS/Android)
- [ ] Après une mise à jour du code, le cache du service worker se met bien à jour (pas de version périmée coincée)
