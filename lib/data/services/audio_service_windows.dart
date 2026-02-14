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
  final _amplitudeController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  AudioServiceWindows(this._wsService);

  Future<void> initialize() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
        _logger.i('🔊 SoLoud Engine Initialized');
      }

      _wsService.audioStream.listen(_playAudioChunk);
      
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
    if (audioData.isEmpty || !_soloud.isInitialized) return;

    try {
      // Usando loadMem para carregar o buffer do WebSocket
      final source = await _soloud.loadMem(
        'chunk_${DateTime.now().millisecondsSinceEpoch}', 
        audioData, 
      );

      // Reproduz com volume normalizado
      final handle = await _soloud.play(source, volume: 1.0);
      
      // Controla o avatar baseado na amplitude do chunk
      double chunkAmplitude = _calculateRMS(audioData);
      _amplitudeController.add(chunkAmplitude);
      
      // Limpa a amplitude após um curto delay para manter o movimento fluido
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_amplitudeController.hasListener) {
          _amplitudeController.add(0.0);
        }
      });

    } catch (e) {
      _logger.w('⚠️ Error playing chunk: $e');
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
    // Normalização neurocientífica: mapeia a amplitude para um movimento de boca perceptível
    return (rms / 32768.0 * 3.5).clamp(0.0, 1.0);
  }

  void dispose() {
    _amplitudeController.close();
    _recordSubscription?.cancel();
    _audioRecorder.dispose();
  }
}
