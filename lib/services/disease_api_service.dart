import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DiseaseApiService {
  // Indoor Plant Doctor API
  static const String baseUrl = 'http://13.61.207.31:8000';
  static const String geminiApiKey =
      'AIzaSyB_VRbPnYksT8hvLKiLbURlwymL7oZZDqI';

  /// Backward-compatible single image wrapper.
  Future<Map<String, dynamic>> predictDisease(
    Uint8List imageBytes,
    String filename,
  ) async {
    return predictDiseaseBatch([imageBytes], [filename]);
  }

  /// Predict disease from multiple images.
  /// Uses multipart key `files` (plural) for each image.
  Future<Map<String, dynamic>> predictDiseaseBatch(
    List<Uint8List> imageBytesList,
    List<String> filenames,
  ) async {
    if (imageBytesList.isEmpty) {
      throw Exception('At least one image is required.');
    }
    if (imageBytesList.length != filenames.length) {
      throw Exception('Image bytes and filenames count must match.');
    }

    final uri = Uri.parse('$baseUrl/predict');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['gemini_api_key'] = geminiApiKey;
      for (int i = 0; i < imageBytesList.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            imageBytesList[i],
            filename: filenames[i],
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final payload = _decodePayload(response.body);

      if (response.statusCode == 200) {
        final report = payload['report']?.toString().trim();
        if (report == null || report.isEmpty) {
          throw Exception(
            'API returned success but no report was included in the response.',
          );
        }
        return payload;
      }

      final serverError = payload['error']?.toString().trim();
      if (serverError != null && serverError.isNotEmpty) {
        throw Exception(serverError);
      }

      throw Exception(
        'Server returned status ${response.statusCode}: ${response.body}',
      );
    } on TimeoutException {
      throw Exception(
        'Request timed out after 45 seconds. Please check server availability.',
      );
    } catch (e) {
      throw Exception('Error connecting to API: $e');
    }
  }

  Map<String, dynamic> _decodePayload(String body) {
    if (body.trim().isEmpty) {
      return {};
    }

    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return {};
  }

  static String getDisplayName(String value) {
    return value.replaceAll('_', ' ');
  }
}
