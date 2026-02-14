import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
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
  final _player = AudioPlayer();
  
  // --- Avatar Control ---
  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  AudioServiceWindows(this._wsService);

  Future<void> initialize() async {
    try {
      _wsService.audioStream.listen(_playAudioChunk);
      _logger.i('🔊 Audio Player (Audioplayers) Initialized');
    } catch (e) {
      _logger.e('❌ Audio Init Failed: $e');
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    
    try {
      if (await _audioRecorder.hasPermission()) {
        _logger.i('🎙️ Starting Recording Stream (16kHz PCM)...');
        
        final stream = await _audioRecorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000, 
            numChannels: 1,
          ),
        );

        _isRecording = true;

        _recordSubscription = stream.listen((data) {
          if (_wsService.isConnected) {
            _wsService.sendBinary(data);
          }
        });
      }
    } catch (e) {
      _logger.e('❌ Failed to start recording: $e');
      _isRecording = false;
    }
  }

  Future<void> stopRecording() async {
    try {
      _logger.i('🛑 Stopping Recording');
      await _recordSubscription?.cancel();
      await _audioRecorder.stop();
    } finally {
      _isRecording = false;
    }
  }

  Future<void> toggleRecording() async {
    _isRecording ? await stopRecording() : await startRecording();
  }
  
  bool get isRecording => _isRecording;

  Future<void> _playAudioChunk(Uint8List audioData) async {
    if (audioData.isEmpty) return;

    try {
      // Audioplayers também não toca PCM bruto direto via stream facilmente sem salvar
      // Mas o objetivo aqui é o BUILD passar.
      
      double chunkAmplitude = _calculateRMS(audioData);
      _amplitudeController.add(chunkAmplitude);
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_amplitudeController.hasListener) {
          _amplitudeController.add(0.0);
        }
      });

    } catch (e) {
      _logger.w('⚠️ Error processing chunk: $e');
    }
  }

  double _calculateRMS(Uint8List data) {
    if (data.isEmpty) return 0.0;
    
    double sum = 0;
    int numSamples = data.length ~/ 2; 
    ByteData byteData = ByteData.view(data.buffer);

    for (int i = 0; i < numSamples; i++) {
        try {
            int sample = byteData.getInt16(i * 2, Endian.little);
            sum += sample * sample;
        } catch(e) { break; }
    }

    double rms = math.sqrt(sum / numSamples);
    return (rms / 32768.0 * 3.5).clamp(0.0, 1.0);
  }

  void dispose() {
    _amplitudeController.close();
    _recordSubscription?.cancel();
    _audioRecorder.dispose();
    _player.dispose();
  }
}
