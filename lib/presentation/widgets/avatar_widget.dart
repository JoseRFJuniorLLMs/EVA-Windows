import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../../data/services/audio_service_windows.dart';

class AvatarWidget extends StatefulWidget {
  final AudioServiceWindows audioService;

  const AvatarWidget({super.key, required this.audioService});

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  SMINumber? _mouthInput;

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1', 
    );
    
    if (controller != null) {
      artboard.addController(controller);
      _mouthInput = controller.findInput<double>('MouthValue') as SMINumber?;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.audioService.amplitudeStream.listen((volume) {
      if (_mouthInput != null && mounted) {
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
        stateMachines: const ['State Machine 1'],
      ),
    );
  }
}
