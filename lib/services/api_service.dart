import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use http://10.0.2.2:8000 for Android Emulator
  // Use http://localhost:8000 for Windows/Web
  final String baseUrl = 'http://localhost:8000'; 

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
}
