// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Arena';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get home => 'Inicio';

  @override
  String get arena => 'Arena';

  @override
  String get debates => 'Debates y Discusiones';

  @override
  String get openDiscussion => 'Discusión Abierta';

  @override
  String get profile => 'Perfil';

  @override
  String get settings => 'Configuración';

  @override
  String get join => 'Unirse';

  @override
  String get create => 'Crear';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get edit => 'Editar';

  @override
  String get send => 'Enviar';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Éxito';

  @override
  String get roomName => 'Nombre de la Sala';

  @override
  String get roomDescription => 'Descripción de la Sala';

  @override
  String get participants => 'Participantes';

  @override
  String participantCount(int count) {
    return '$count participantes';
  }

  @override
  String get speakingTime => 'Tiempo de Intervención';

  @override
  String get timer => 'Temporizador';

  @override
  String get startTimer => 'Iniciar Temporizador';

  @override
  String get pauseTimer => 'Pausar Temporizador';

  @override
  String get resetTimer => 'Reiniciar Temporizador';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Activar Audio';

  @override
  String get raiseHand => 'Levantar Mano';

  @override
  String get lowerHand => 'Bajar Mano';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Escribe un mensaje...';

  @override
  String get noMessagesYet => 'Aún no hay mensajes';

  @override
  String get beFirstToSend => '¡Sé el primero en enviar un mensaje!';

  @override
  String get moderator => 'Moderador';

  @override
  String get speaker => 'Orador';

  @override
  String get audience => 'Audiencia';

  @override
  String get judge => 'Juez';

  @override
  String get affirmative => 'Afirmativo';

  @override
  String get negative => 'Negativo';

  @override
  String get createRoom => 'Crear Sala';

  @override
  String get joinRoom => 'Unirse a Sala';

  @override
  String get leaveRoom => 'Salir de Sala';

  @override
  String get endRoom => 'Terminar Sala';

  @override
  String get privateRoom => 'Sala Privada';

  @override
  String get publicRoom => 'Sala Pública';

  @override
  String get password => 'Contraseña';

  @override
  String get incorrectPassword => 'Contraseña incorrecta';

  @override
  String get roomRequiresPassword =>
      'Esta sala requiere una contraseña para ingresar.';

  @override
  String get activeDiscussions => 'Discusiones Activas';

  @override
  String get noActiveDiscussions => 'No hay discusiones activas';

  @override
  String get beFirstToCreate =>
      '¡Sé el primero en crear una sala de discusión!';

  @override
  String roomsAvailable(int count) {
    return '$count salas disponibles';
  }

  @override
  String get darkMode => 'Modo Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get accessibility => 'Accesibilidad';

  @override
  String get largeText => 'Texto Grande';

  @override
  String get highContrast => 'Alto Contraste';

  @override
  String get screenReader => 'Soporte para Lector de Pantalla';

  @override
  String get connectionStatus => 'Estado de Conexión';

  @override
  String get connected => 'Conectado';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get reconnecting => 'Reconectando...';

  @override
  String get offline => 'Sin Conexión';

  @override
  String get retryConnection => 'Reintentar Conexión';
}
