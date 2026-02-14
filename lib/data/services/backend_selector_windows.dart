import 'dart:io';
import 'package:logger/logger.dart';

class BackendSelectorWindows {
  static const String gcpIp = '136.113.25.218';
  static const String doIp = '104.248.219.200';
  
  static final Logger _logger = Logger();
  static String? _activeIp;

  static String get wsBaseUrl {
    final ip = _activeIp ?? gcpIp;
    return 'ws://$ip:8090/ws/pcm';
  }

  /// Tries to find an available backend.
  static Future<void> init() async {
    _logger.i('📡 Checking Windows backend availability...');
    
    // Try GCP first
    if (await _checkHealth(gcpIp)) {
      _logger.i('✅ GCP Backend (136.113.25.218) is UP');
      _activeIp = gcpIp;
      return;
    }

    // Try DigitalOcean
    if (await _checkHealth(doIp)) {
      _logger.i('✅ DigitalOcean Backend (104.248.219.200) is UP');
      _activeIp = doIp;
      return;
    }

    _logger.w('⚠️ No backend responded to health check. Defaulting to GCP.');
    _activeIp = gcpIp;
  }

  static Future<bool> _checkHealth(String ip) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://$ip:8000/api/health'))
          .timeout(const Duration(seconds: 3));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
