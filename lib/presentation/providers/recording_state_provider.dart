import 'package:flutter/material.dart';

class RecordingStateProvider extends ChangeNotifier {
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  void setRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  void toggle() {
    _isRecording = !_isRecording;
    notifyListeners();
  }
}
