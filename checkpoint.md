# CHECKPOINT - EVA-Windows
**Data:** 2026-02-19
**Status:** ~40% completo - esqueleto funcional, features principais sao stubs

---

## O QUE E O PROJETO
EVA-Windows e uma aplicacao Flutter Desktop para Windows que atua como cliente de assistente de voz IA. Conecta-se ao backend EVA-Mind via WebSocket, captura audio do microfone e recebe respostas de audio.

**Tech Stack:** Flutter (Dart) + Windows Desktop + bitsdojo_window + WebSocket + PCM Audio

---

## ESTRUTURA DE ARQUIVOS
```
EVA-Windows/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── service_locator.dart               # GetIt DI
│   ├── core/                              # VAZIO
│   ├── domain/models/                     # VAZIO
│   ├── data/
│   │   ├── repositories/                  # VAZIO
│   │   └── services/
│   │       ├── backend_selector_windows.dart  # Health check auto-select backend
│   │       ├── websocket_service.dart         # WS connect/reconnect
│   │       └── audio_service_windows.dart     # Mic recording + playback (STUB)
│   └── presentation/
│       ├── providers/recording_state_provider.dart  # UNUSED
│       ├── screens/desktop_home.dart                # Tela principal
│       └── widgets/avatar_widget.dart               # Avatar placeholder
├── assets/eva_avatar.riv               # STUB (16 bytes, invalido)
├── windows/                            # Native Windows runner (CMake)
├── test/widget_test.dart               # DEFAULT boilerplate (NAO funciona)
└── .env                                # Placeholder (UTF-16 BOM - problema)
```

---

## O QUE FUNCIONA
1. App startup + window management (borderless 450x750, bitsdojo_window)
2. Backend auto-selection (health check em 2 IPs hardcoded)
3. WebSocket service (connect/reconnect, split text/binary streams)
4. Gravacao de microfone (PCM 16-bit, 16kHz mono)
5. Calculo RMS de amplitude
6. Custom window chrome (title bar, minimize/maximize/close)
7. Toggle button de gravacao
8. Display de mensagens WebSocket

---

## O QUE FALTA FAZER
1. **AUDIO PLAYBACK** - `_playAudioChunk()` NAO toca audio. AudioPlayer criado mas nunca usado. EVA NAO FALA.
2. **Avatar Rive** - Totalmente comentado. Rive removido por falhas de build (ClangCL). So mostra Icons.face
3. **RecordingStateProvider** - Criado mas NUNCA usado na UI (dead code)
4. **Diretorios vazios** - core/, domain/models/, data/repositories/
5. **System tray** - Declarado em pubspec mas zero codigo implementado
6. **window_manager** - Declarado em pubspec mas nunca usado
7. **UI de estado/erro** - Sem feedback visual de conexao, erros, permissoes
8. **Configuracoes** - Tudo hardcoded, sem UI de settings

---

## BUGS CRITICOS
1. **Audio Playback nunca funciona** - `_playAudioChunk()` so calcula RMS, nao toca nada
2. **URL WebSocket errada** - `desktop_home.dart:19` hardcoda `ws://localhost:8080/v1/ws`, ignorando BackendSelector que retorna `ws://IP:8090/ws/pcm`
3. **Encoding do .env** - Arquivo em UTF-16 LE (BOM), flutter_dotenv espera UTF-8
4. **Estado UI nao reativo** - `setState` chama `toggleRecording()` async sem await, icone fica stale
5. **Divisao por zero** - `_calculateRMS()` crash com chunk de 1 byte (numSamples=0)
6. **Widget test boilerplate** - Testa counter app que nao existe, sempre falha

---

## DEPENDENCIAS
| Pacote | Versao | Status |
|--------|--------|--------|
| bitsdojo_window | ^0.1.6 | Funciona |
| record | ^6.2.0 | Funciona |
| audioplayers | ^6.5.1 | NAO implementado |
| web_socket_channel | ^2.4.0 | Funciona |
| get_it | ^7.6.0 | Funciona |
| flutter_dotenv | ^5.1.0 | Funciona (mas .env com encoding errado) |
| system_tray | ^2.0.2 | NAO usado |
| window_manager | ^0.3.7 | NAO usado |
| permission_handler | ^11.3.0 | Possivelmente desnecessario |

**Removidos:** rive ^0.11.1 (ClangCL), flutter_soloud ^2.0.0 (conflitos)

---

## ARQUIVOS PARA DELETAR (LIXO)
- SOLUCAO_BUILD_WINDOWS.md (v1 a v6) - 6 arquivos de historico de build
- gemini_3_full_implementation.md - blueprint antigo superseded
- build_error_*.log (9+ arquivos de log)
- build_windows_verbose.txt (449KB)
- windows_build_failure.log (473KB)
- analyze_windows_build.py - script one-off
- implement_eva_windows.py - script one-off
- fazer.txt / fazer2.txt - TODOs antigos
- EVA-Mind_Windows_Migration_Guide.docx - doc historico
