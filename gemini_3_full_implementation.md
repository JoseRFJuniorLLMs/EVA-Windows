Compreendido. Como Arquiteto Sênior do projeto, estruturei a migração do **EVA-Mind** para a arquitetura **EVA-Windows** seguindo rigorosamente os padrões de Desktop Nativo definidos.

Aqui está o código fonte completo e modularizado.

### 1. Dependências do Projeto

Substituímos a stack mobile pela stack desktop de alta performance.

**File:** `pubspec.yaml`
```yaml
name: eva_windows
description: EVA Mind Desktop Assistant - Windows Native Implementation
version: 1.0.0+1
publish_to: 'none'

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # --- UI & Window Management ---
  bitsdojo_window: ^0.1.6       # Janelas customizadas sem borda
  system_tray: ^2.0.2           # Ícone na bandeja do sistema
  window_manager: ^0.3.7        # Gerenciamento de estado da janela

  # --- Core: Audio & Avatar ---
  rive: ^0.13.4                 # Engine de animação vetorial
  record: ^5.1.0                # Captura de áudio nativa (Windows)
  flutter_soloud: ^2.0.0        # Engine de áudio C++ (Baixa latência)
  path_provider: ^2.1.2         # Sistema de arquivos

  # --- Logic & Comm ---
  web_socket_channel: ^2.4.0    # Comunicação Bidirecional
  get_it: ^7.6.0                # Injeção de Dependência
  logger: ^2.0.0                # Logs estruturados
  flutter_dotenv: ^5.1.0        # Variáveis de ambiente
  permission_handler: ^11.3.0   # Permissões de microfone no Windows

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/eva_avatar.riv    # OBRIGATÓRIO: Seu arquivo Rive
    - .env
```

---

### 2. Injeção de Dependências (Service Locator)

Centralizamos a inicialização dos serviços para evitar acoplamento forte na UI.

**File:** `lib/service_locator.dart`
```dart
import 'package:get_it/get_it.dart';
import 'services/websocket_service.dart';
import 'services/audio_service_windows.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 1. WebSocket Service (Singleton)
  // Certifique-se de configurar a URL correta no .env ou aqui
  getIt.registerSingleton<WebSocketService>(WebSocketService());

  // 2. Audio Service (Singleton - Depende do WebSocket)
  getIt.registerSingleton<AudioServiceWindows>(
    AudioServiceWindows(getIt<WebSocketService>()),
  );

  // Inicialização assíncrona dos motores de áudio
  await getIt<AudioServiceWindows>().initialize();
}
```

---

### 3. Serviço de WebSocket (Suporte Binário)

Adaptado para separar comandos de texto (JSON) e fluxo de áudio (PCM Bytes).

**File:** `lib/services/websocket_service.dart`
```dart
import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logger/logger.dart';

class WebSocketService {
  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  
  // Streams separados para tipos de dados diferentes
  final _textController = StreamController<String>.broadcast();
  final _audioController = StreamController<Uint8List>.broadcast();

  Stream<String> get textStream => _textController.stream;
  Stream<Uint8List> get audioStream => _audioController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String url) async {
    try {
      _logger.i('🔌 Connecting to WebSocket: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          if (message is String) {
            // Mensagens de controle/texto (JSON)
            _textController.add(message);
          } else if (message is List<int>) {
            // Stream de Áudio (PCM) vindo do Gemini/Backend
            _audioController.add(Uint8List.fromList(message));
          }
        },
        onError: (error) => _logger.e('WS Error: $error'),
        onDone: () {
          _logger.w('WS Disconnected');
          _channel = null;
        },
      );
    } catch (e) {
      _logger.e('Connection failed: $e');
    }
  }

  // Envia texto (Comandos JSON)
  void sendText(String text) {
    if (isConnected) {
      _channel!.sink.add(text);
    }
  }

  // Envia Binário (Mic Stream -> Backend)
  void sendBinary(Uint8List data) {
    if (isConnected) {
      _channel!.sink.add(data);
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
```

---

### 4. O Coração: Audio Service (Windows Nativo)

Esta classe orquestra a entrada (Mic) e saída (Speaker) com baixíssima latência, calculando a amplitude para o Avatar.

**File:** `lib/services/audio_service_windows.dart`
```dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:logger/logger.dart';
import 'websocket_service.dart';

class AudioServiceWindows {
  final Logger _logger = Logger();
  final WebSocketService _wsService;
  
  // --- Input (Microfone) ---
  final _audioRecorder = AudioRecorder();
  StreamSubscription? _recordSubscription;
  bool _isRecording = false;

  // --- Output (Speaker) ---
  final _soloud = SoLoud.instance;
  
  // --- Avatar Control ---
  // Stream de 0.0 a 1.0 para controlar a boca do Rive
  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  AudioServiceWindows(this._wsService);

  Future<void> initialize() async {
    try {
      // 1. Inicializa Engine de Output (C++)
      if (!_soloud.isInitialized) {
        await _soloud.init();
        _logger.i('🔊 SoLoud Engine Initialized');
      }

      // 2. Ouve o áudio chegando do WebSocket (Do Servidor)
      _wsService.audioStream.listen((audioChunk) {
        _playAudioChunk(audioChunk);
      });
      
    } catch (e) {
      _logger.e('❌ Audio Init Failed: $e');
    }
  }

  // --- Gravação (Input) ---

  Future<void> startRecording() async {
    if (_isRecording) return;
    
    if (await _audioRecorder.hasPermission()) {
      _logger.i('🎙️ Starting Recording Stream (16kHz PCM)...');
      
      // Inicia stream raw PCM 16-bit
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000, 
          numChannels: 1,
        ),
      );

      _isRecording = true;

      _recordSubscription = stream.listen((data) {
        // 1. Envia para o Backend
        _wsService.sendBinary(data);

        // 2. Calcula amplitude para feedback visual (opcional: mostrar que está ouvindo)
        // double micVolume = _calculateRMS(data);
        // _amplitudeController.add(micVolume * 0.5); // Feedback visual suave
      });
    }
  }

  Future<void> stopRecording() async {
    _logger.i('🛑 Stopping Recording');
    await _recordSubscription?.cancel();
    await _audioRecorder.stop();
    _isRecording = false;
  }

  void toggleRecording() {
    _isRecording ? stopRecording() : startRecording();
  }
  
  bool get isRecording => _isRecording;

  // --- Reprodução (Output) ---

  Future<void> _playAudioChunk(Uint8List audioData) async {
    if (audioData.isEmpty) return;

    try {
      // 1. Carrega PCM da memória (RAM)
      // Nota: Para produção extrema, usar buffer circular. 
      // loadMem é suficiente para chunks de frases curtas.
      final source = await _soloud.loadMem(
        'stream_chunk', 
        audioData, 
        LoadMode.memory, 
        // Auto-destroy garante que a memória seja liberada após tocar
      );

      // 2. Toca o som
      await _soloud.play(source);

      // 3. Anima o Avatar baseado no chunk
      // Como não temos FFT em tempo real fácil aqui, simulamos amplitude média do chunk
      double chunkAmplitude = _calculateRMS(audioData);
      
      // Simula decaimento da boca (abre e fecha rápido)
      _amplitudeController.add(chunkAmplitude);
      Future.delayed(const Duration(milliseconds: 150), () {
        _amplitudeController.add(0.0);
      });

    } catch (e) {
      _logger.w('⚠️ Error playing chunk: $e');
    }
  }

  // --- Utilitários ---

  double _calculateRMS(Uint8List data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0;
    // PCM 16bit = 2 bytes por sample
    int numSamples = data.length ~/ 2; 
    ByteData byteData = ByteData.view(data.buffer);

    for (int i = 0; i < numSamples; i++) {
      int sample = byteData.getInt16(i * 2, Endian.little);
      sum += sample * sample;
    }

    double rms = math.sqrt(sum / numSamples);
    // Normaliza (Int16 max é 32768)
    // Multiplica por fator de ganho (2.5) para ficar mais expressivo visualmente
    return (rms / 32768.0 * 2.5).clamp(0.0, 1.0);
  }
}
```

---

### 5. Avatar Widget (Interface Rive)

Conecta o stream de amplitude ao input numérico da State Machine do Rive.

**File:** `lib/presentation/widgets/avatar_widget.dart`
```dart
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../services/audio_service_windows.dart';

class AvatarWidget extends StatefulWidget {
  final AudioServiceWindows audioService;

  const AvatarWidget({super.key, required this.audioService});

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  SMINumber? _mouthInput;
  // SMIBool? _isListeningInput; // Caso seu Rive tenha estado de "Ouvindo"

  void _onRiveInit(Artboard artboard) {
    // IMPORTANTE: O nome 'FaceMachine' deve ser igual ao definido no editor do Rive
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1', // Nome padrão comum, verifique seu arquivo .riv
    );
    
    if (controller != null) {
      artboard.addController(controller);
      // Nome do input numérico que controla a boca (0 a 100)
      _mouthInput = controller.findInput<double>('MouthValue') as SMINumber?;
    }
  }

  @override
  void initState() {
    super.initState();
    // Escuta o áudio para mover a boca
    widget.audioService.amplitudeStream.listen((volume) {
      if (_mouthInput != null && mounted) {
        // Converte 0.0-1.0 para 0-100 (Padrão Rive)
        _mouthInput!.value = volume * 100;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      width: 400,
      child: RiveAnimation.asset(
        'assets/eva_avatar.riv',
        fit: BoxFit.contain,
        onInit: _onRiveInit,
        stateMachines: const ['State Machine 1'], // Garante que a máquina inicie
      ),
    );
  }
}
```

---

### 6. Interface Desktop (Janela Customizada)

Layout limpo, escuro e com barra de título integrada.

**File:** `lib/presentation/screens/desktop_home.dart`
```dart
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:get_it/get_it.dart';
import '../../services/audio_service_windows.dart';
import '../../services/websocket_service.dart';
import '../widgets/avatar_widget.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  final audioService = GetIt.I<AudioServiceWindows>();
  final wsService = GetIt.I<WebSocketService>();
  
  // URL do Backend (Idealmente viria do .env)
  final String _wsUrl = 'ws://localhost:8080/v1/ws'; 

  @override
  void initState() {
    super.initState();
    // Conecta ao iniciar
    wsService.connect(_wsUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Fundo Dark Moderno
      body: Column(
        children: [
          // --- Custom Title Bar ---
          WindowTitleBarBox(
            child: Row(
              children: [
                Expanded(child: MoveWindow()), // Área para arrastar a janela
                const WindowButtons(), // Controles Windows
              ],
            ),
          ),
          
          // --- Main Content ---
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  AvatarWidget(audioService: audioService),
                  
                  const SizedBox(height: 30),
                  
                  // Status Indicator (Texto simples para debug)
                  StreamBuilder<String>(
                    stream: wsService.textStream,
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.hasData ? snapshot.data! : "EVA Online",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Mic Control
                  GestureDetector(
                    onLongPress: () {
                        // Opcional: Push-to-talk
                    },
                    child: FloatingActionButton(
                      backgroundColor: Colors.cyanAccent,
                      onPressed: () {
                        setState(() {
                          audioService.toggleRecording();
                        });
                      },
                      child: Icon(
                        audioService.isRecording ? Icons.stop : Icons.mic,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Botões da Janela (Min, Max, Close)
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});
  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: const Color(0xFF805306),
      mouseOver: const Color(0xFFF6A00C),
      mouseDown: const Color(0xFF805306),
      iconMouseOver: const Color(0xFF805306),
      iconMouseDown: const Color(0xFFFFD500),
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: const Color(0xFF805306),
      iconMouseOver: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}
```

---

### 7. Entry Point (`main.dart`)

Configuração crítica da janela do Windows.

**File:** `lib/main.dart`
```dart
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'service_locator.dart';
import 'presentation/screens/desktop_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializa Serviços (Áudio, WS)
  await setupServiceLocator();

  runApp(const EvaMindDesktopApp());

  // 2. Configura a Janela Nativa
  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(450, 750); // Formato "Portrait" de Assistente
    win.minSize = const Size(400, 600);
    win.size = initialSize;
    win.alignment = Alignment.centerRight; // Abre no canto direito da tela
    win.title = "EVA Mind";
    win.show();
  });
}

class EvaMindDesktopApp extends StatelessWidget {
  const EvaMindDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EVA Mind',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const DesktopHome(),
    );
  }
}
```

### Notas Finais de Implementação

1.  **Arquivo Rive:** Você **DEVE** colocar um arquivo `.riv` válido em `assets/eva_avatar.riv`. Abra esse arquivo no editor do Rive e verifique o nome da *State Machine* (padrão costuma ser "State Machine 1") e o nome do Input numérico (eu usei "MouthValue" no código, ajuste conforme necessário).
2.  **Permissões Windows:** A lib `record` geralmente cuida disso, mas se tiver problemas, verifique as configurações de privacidade de microfone do Windows 10/11 para permitir que aplicativos desktop acessem o hardware.
3.  **Backend:** O código espera um WebSocket em `ws://localhost:8080/v1/ws`. Certifique-se que seu servidor Python/Node esteja rodando e aceitando blobs binários.