import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/services/backend_selector_windows.dart';
import 'service_locator.dart';
import 'presentation/screens/desktop_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await BackendSelectorWindows.init();
  await setupServiceLocator();

  runApp(const EvaMindDesktopApp());

  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(450, 750);
    win.minSize = const Size(400, 600);
    win.size = initialSize;
    win.alignment = Alignment.centerRight;
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
