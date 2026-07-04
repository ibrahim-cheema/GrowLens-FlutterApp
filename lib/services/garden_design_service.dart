import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'image_optimizer.dart';

class GardenDesignService {
  // Optional override:
  // flutter run --dart-define=GARDEN_API_BASE_URL=http://192.168.x.x:8000
  static const String _overrideBaseUrl = String.fromEnvironment(
    'GARDEN_API_BASE_URL',
    defaultValue: '',
  );

  // Optional override:
  // flutter run --dart-define=GARDEN_API_TIMEOUT_SECONDS=7200
  static const String _timeoutSecondsValue = String.fromEnvironment(
    'GARDEN_API_TIMEOUT_SECONDS',
    defaultValue: '7200',
  );

  static int get _timeoutSeconds {
    final parsed = int.tryParse(_timeoutSecondsValue);
    return (parsed == null || parsed <= 0) ? 7200 : parsed;
  }

  static const String _primaryBaseUrl = 'http://10.100.21.243:8000';
  static const String _productionBaseUrl = 'http://13.63.8.251:8000';
  static const String _localNetworkBaseUrl = 'http://192.168.18.16:8000';

  static List<String> get _candidateBaseUrls {
    final candidates = <String>[];

    if (_overrideBaseUrl.isNotEmpty) {
      candidates.add(_overrideBaseUrl);
    }

    if (kIsWeb) {
      candidates.addAll([
        _primaryBaseUrl,
        'http://127.0.0.1:8000',
        _productionBaseUrl,
      ]);
      return candidates;
    }

    candidates.addAll([
      'http://127.0.0.1:8000',
      _localNetworkBaseUrl,
      _primaryBaseUrl,
      _productionBaseUrl,
      'http://10.0.2.2:8000',
    ]);

    return candidates;
  }

  /// Sends the selected garden image and preferences to /design-garden/.
  Future<Map<String, dynamic>> generateGardenDesign({
    required XFile imageFile,
    required String city,
    required String style,
  }) async {
    try {
      var cleanCity = city.trim();
      if (cleanCity.contains(',')) {
        cleanCity = cleanCity.split(',')[0].trim();
      }
      if (cleanCity.isEmpty) {
        cleanCity = 'Faisalabad';
      }

      final cleanStyle = style.trim().isEmpty ? 'Mughal' : style.trim();

      Exception? lastError;

      for (final baseUrl in _candidateBaseUrls) {
        try {
          final response = await _sendDesignRequest(
            baseUrl: baseUrl,
            imageFile: imageFile,
            city: cleanCity,
            style: cleanStyle,
          );

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is! Map<String, dynamic>) {
              throw Exception('Invalid response format from server.');
            }

            final base64Image = decoded['designed_image_base64'] as String?;
            final aiAnalysis = decoded['ai_analysis'] as String?;

            if (base64Image == null || base64Image.isEmpty) {
              throw Exception('Server response missing designed image.');
            }
            if (aiAnalysis == null || aiAnalysis.isEmpty) {
              throw Exception('Server response missing AI analysis.');
            }

            return decoded;
          }

          lastError = Exception(
            'Server error ${response.statusCode}: ${response.body}',
          );
        } on TimeoutException {
          lastError = Exception(
            'The request to $baseUrl timed out after $_timeoutSeconds seconds.',
          );
        } on http.ClientException {
          lastError = Exception('Unable to connect to backend on $baseUrl.');
        }
      }

      throw lastError ??
          Exception(
            'Unable to connect to backend. Tried: ${_candidateBaseUrls.join(', ')}',
          );
    } on TimeoutException {
      throw Exception(
        'The request timed out after $_timeoutSeconds seconds. Please try again.',
      );
    } catch (e) {
      throw Exception('Failed to generate garden design: $e');
    }
  }

  Future<http.Response> _sendDesignRequest({
    required String baseUrl,
    required XFile imageFile,
    required String city,
    required String style,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/design-garden/'),
    );

    if (kIsWeb) {
      final bytes = await ImageOptimizer.compressImage(
            imageFile,
            maxWidth: 1024,
            maxHeight: 1024,
            quality: 75,
          ) ??
          await imageFile.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.name,
        ),
      );
    } else {
      final compressedBytes = await ImageOptimizer.compressImage(
            imageFile,
            maxWidth: 1024,
            maxHeight: 1024,
            quality: 75,
          ) ??
          await imageFile.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          compressedBytes,
          filename: imageFile.name,
        ),
      );
    }

    request.fields['city'] = city;
    request.fields['style'] = style;

    final streamedResponse = await request
        .send()
        .timeout(Duration(seconds: _timeoutSeconds));
    return http.Response.fromStream(streamedResponse);
  }
}
