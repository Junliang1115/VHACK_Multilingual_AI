import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  Future<Map<String, dynamic>> translate({
    required String text,
    required String dialect,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'target_dialect': dialect,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to translate: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<Map<String, dynamic>> summarize(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/summarize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to summarize');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<Map<String, dynamic>> scanScreen(
      {List<int>? region, String? lang, bool reset = false}) async {
    final url = '$baseUrl/scan-screen';
    debugPrint("DEBUG: ApiService POSTing to $url");
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (region != null) 'region': region,
              if (lang != null) 'lang': lang,
              'reset': reset,
            }),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint("DEBUG: ApiService Response Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("DEBUG: ApiService Request Error: ${response.body}");
        throw Exception('Failed to scan screen: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("DEBUG: ApiService Error occurred: $e");
      if (e is TimeoutException) {
        throw Exception(
            'Connection timeout to $url. Check backend is running.');
      }
      throw Exception('Connection error: $e');
    }
  }
}
