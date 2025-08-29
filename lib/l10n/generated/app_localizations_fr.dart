// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Arena';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get home => 'Accueil';

  @override
  String get arena => 'Arena';

  @override
  String get debates => 'Débats et Discussions';

  @override
  String get openDiscussion => 'Discussion Ouverte';

  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Paramètres';

  @override
  String get join => 'Rejoindre';

  @override
  String get create => 'Créer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get send => 'Envoyer';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get roomName => 'Nom de la Salle';

  @override
  String get roomDescription => 'Description de la Salle';

  @override
  String get participants => 'Participants';

  @override
  String participantCount(int count) {
    return '$count participants';
  }

  @override
  String get speakingTime => 'Temps de Parole';

  @override
  String get timer => 'Minuteur';

  @override
  String get startTimer => 'Démarrer le Minuteur';

  @override
  String get pauseTimer => 'Mettre en Pause';

  @override
  String get resetTimer => 'Réinitialiser';

  @override
  String get mute => 'Muet';

  @override
  String get unmute => 'Activer le Son';

  @override
  String get raiseHand => 'Lever la Main';

  @override
  String get lowerHand => 'Baisser la Main';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Tapez un message...';

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get beFirstToSend => 'Soyez le premier à envoyer un message !';

  @override
  String get moderator => 'Modérateur';

  @override
  String get speaker => 'Orateur';

  @override
  String get audience => 'Audience';

  @override
  String get judge => 'Juge';

  @override
  String get affirmative => 'Affirmatif';

  @override
  String get negative => 'Négatif';

  @override
  String get createRoom => 'Créer une Salle';

  @override
  String get joinRoom => 'Rejoindre la Salle';

  @override
  String get leaveRoom => 'Quitter la Salle';

  @override
  String get endRoom => 'Terminer la Salle';

  @override
  String get privateRoom => 'Salle Privée';

  @override
  String get publicRoom => 'Salle Publique';

  @override
  String get password => 'Mot de Passe';

  @override
  String get incorrectPassword => 'Mot de passe incorrect';

  @override
  String get roomRequiresPassword =>
      'Cette salle nécessite un mot de passe pour entrer.';

  @override
  String get activeDiscussions => 'Discussions Actives';

  @override
  String get noActiveDiscussions => 'Aucune discussion active';

  @override
  String get beFirstToCreate =>
      'Soyez le premier à créer une salle de discussion !';

  @override
  String roomsAvailable(int count) {
    return '$count salles disponibles';
  }

  @override
  String get darkMode => 'Mode Sombre';

  @override
  String get language => 'Langue';

  @override
  String get notifications => 'Notifications';

  @override
  String get accessibility => 'Accessibilité';

  @override
  String get largeText => 'Texte Large';

  @override
  String get highContrast => 'Contraste Élevé';

  @override
  String get screenReader => 'Support Lecteur d\'Écran';

  @override
  String get connectionStatus => 'État de la Connexion';

  @override
  String get connected => 'Connecté';

  @override
  String get disconnected => 'Déconnecté';

  @override
  String get reconnecting => 'Reconnexion...';

  @override
  String get offline => 'Hors Ligne';

  @override
  String get retryConnection => 'Réessayer la Connexion';
}
