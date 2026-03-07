// Get the reponse from the backend API

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TranslationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  String _translatedText = "";
  String _summary = "";
  String _currentDialect = "Kedah";
  bool _isLoading = false;
  String _errorMessage = "";

  String get translatedText => _translatedText;
  String get summary => _summary;
  String get currentDialect => _currentDialect;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  void setDialect(String dialect) {
    _currentDialect = dialect;
    notifyListeners();
  }

  Future<void> translateText(String text) async {
    if (text.isEmpty) return;

    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      final result = await _apiService.translate(
        text: text,
        dialect: _currentDialect,
      );
      
      _translatedText = result['translated_text'];
      _summary = result['summary'] ?? "No summary available.";
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
