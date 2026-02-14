import 'package:get_it/get_it.dart';
import 'data/services/websocket_service.dart';
import 'data/services/audio_service_windows.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 1. WebSocket Service (Singleton)
  getIt.registerSingleton<WebSocketService>(WebSocketService());

  // 2. Audio Service (Singleton - Depende do WebSocket)
  getIt.registerSingleton<AudioServiceWindows>(
    AudioServiceWindows(getIt<WebSocketService>()),
  );

  // Inicialização assíncrona dos motores de áudio
  await getIt<AudioServiceWindows>().initialize();
}
