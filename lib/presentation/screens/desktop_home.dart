import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:get_it/get_it.dart';
import '../../data/services/audio_service_windows.dart';
import '../../data/services/websocket_service.dart';
import '../widgets/avatar_widget.dart';

class DesktopHome extends StatefulWidget {
  const DesktopHome({super.key});

  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}

class _DesktopHomeState extends State<DesktopHome> {
  final audioService = GetIt.I<AudioServiceWindows>();
  final wsService = GetIt.I<WebSocketService>();
  
  final String _wsUrl = 'ws://localhost:8080/v1/ws'; 

  @override
  void initState() {
    super.initState();
    wsService.connect(_wsUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          WindowTitleBarBox(
            child: Row(
              children: [
                Expanded(child: MoveWindow()), 
                const WindowButtons(),
              ],
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AvatarWidget(audioService: audioService),
                  const SizedBox(height: 30),
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
                  FloatingActionButton(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
