// Get the reponse from the backend API

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/api_service.dart';

class TranslationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  TranslationProvider() {
    debugPrint("DEBUG: TranslationProvider constructor called, setting up overlayListener.");
    FlutterOverlayWindow.overlayListener.listen((event) {
      debugPrint("DEBUG: Received event from overlayListener: $event");
      if (event == "SYNC_START_SCAN") {
        debugPrint("DEBUG: Syncing START_SCAN from overlay");
        _isScanning = true;
        notifyListeners();
      } else if (event == "SYNC_STOP_SCAN") {
        debugPrint("DEBUG: Syncing STOP_SCAN from overlay");
        _isScanning = false;
        notifyListeners();
        // Bring app back to foreground when scanning stops
        const MethodChannel('com.example.gov_translator/app_channel').invokeMethod('bringToForeground');
      } else if (event is String && event.startsWith("TEXT:")) {
        final newText = event.substring(5);
        debugPrint("DEBUG: Appending synced text length: ${newText.length}");
        if (_sourceText.isEmpty) {
          _sourceText = newText;
        } else {
          _sourceText += "\n" + newText;
        }
        notifyListeners();
      }
    });
  }

  String _translatedText = "";
  String _summary = "";
  String _currentDialect = "Kedah";
  String _sourceText = "";
  bool _isLoading = false;
  String _errorMessage = "";
  bool _isScanning = false;

  String get sourceText => _sourceText;
  String get translatedText => _translatedText;
  String get summary => _summary;
  String get currentDialect => _currentDialect;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String get errorMessage => _errorMessage;

  void setSourceText(String text) {
    _sourceText = text;
    notifyListeners();
  }

  void setDialect(String dialect) {
    _currentDialect = dialect;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = "";
    notifyListeners();
  }

  Future<void> translateText(String text) async {
    if (text.isEmpty) return;
    _sourceText = text;

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

  Future<void> scanScreen({bool reset = false}) async {
    debugPrint("DEBUG: scanScreen called with reset=$reset");
    _isLoading = true;
    _errorMessage = "";
    notifyListeners();

    try {
      debugPrint("DEBUG: Calling apiService.scanScreen...");
      final result = await _apiService.scanScreen(reset: reset);
      String newText = result['extracted_text'];
      debugPrint("DEBUG: OCR Success. Extracted length: ${newText.length}");
      
      if (newText.isNotEmpty) {
        if (_sourceText.isEmpty) {
          _sourceText = newText;
        } else {
          _sourceText += "\n" + newText;
        }
      }
    } catch (e) {
      debugPrint("DEBUG: OCR Error caught in provider: $e");
      _errorMessage = e.toString();
      // If we are in continuous mode and hit an error, we might want to stop
      stopContinuousScan();
    } finally {
      _isLoading = false;
      debugPrint("DEBUG: OCR finished. isLoading set to false.");
      notifyListeners();
    }
  }

  Future<void> startContinuousScan() async {
    if (_isScanning) return;
    
    _isScanning = true;
    notifyListeners();
    
    // Reset history once at the start of a session
    await scanScreen(reset: true);
    
    while (_isScanning) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isScanning) break;
      await scanScreen(reset: false);
    }
  }

  void stopContinuousScan() {
    _isScanning = false;
    notifyListeners();
    try {
      FlutterOverlayWindow.shareData("STOPPED");
    } catch (_) {}
  }
}
