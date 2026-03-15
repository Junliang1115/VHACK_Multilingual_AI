import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/api_service.dart';

class FloatingOverlay extends StatefulWidget {
  const FloatingOverlay({super.key});

  @override
  State<FloatingOverlay> createState() => _FloatingOverlayState();
}

class _FloatingOverlayState extends State<FloatingOverlay> {
  bool isScanning = false;
  bool _isRequestInFlight = false;
  bool _isStopping = false;
  Timer? _scanTimer;
  final ApiService _apiService = ApiService();
  final List<String> _sessionLines = [];

  void _addSessionText(String rawText) {
    for (final line in rawText.split('\n')) {
      final clean = line.trim();
      if (clean.isNotEmpty && !_sessionLines.contains(clean)) {
        _sessionLines.add(clean);
      }
    }
  }

  String _compactForLog(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 220) {
      return singleLine;
    }
    return '${singleLine.substring(0, 220)}...';
  }

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'STOPPED' && mounted) {
        _stopScanning();
      }
    });
  }

  Future<void> _startScanning() async {
    if (isScanning) {
      return;
    }

    // Defensive reset: if a previous stop flow was interrupted, recover here.
    if (_isStopping) {
      debugPrint("DEBUG (Overlay): Recovering from stale stopping state.");
      _isStopping = false;
    }

    _scanTimer?.cancel();
    _scanTimer = null;
    _sessionLines.clear();
    setState(() => isScanning = true);
    debugPrint("DEBUG (Overlay): Starting scan session.");
    // Notify main app that scanning actually started on overlay side
    FlutterOverlayWindow.shareData("SYNC_START_SCAN");

    // First call resets backend history; forward the first OCR payload too.
    _isRequestInFlight = true;
    try {
      final firstResult = await _apiService.scanScreen(reset: true);
      if (_isStopping || !mounted || !isScanning) {
        return;
      }
      final firstText = firstResult['extracted_text'];
      if (firstText != null && firstText.toString().isNotEmpty) {
        _addSessionText(firstText.toString());
        debugPrint(
            "DEBUG (Overlay OCR first): ${_compactForLog(firstText.toString())}");
        FlutterOverlayWindow.shareData("TEXT:${firstText.toString()}");
      } else {
        debugPrint("DEBUG (Overlay OCR first): response was empty.");
      }
    } catch (e) {
      debugPrint("Overlay first-scan API error: $e");
      if (!_isStopping) {
        FlutterOverlayWindow.shareData("ERROR:${e.toString()}");
        await _stopScanning();
      }
      return;
    } finally {
      _isRequestInFlight = false;
    }

    if (_isStopping || !mounted || !isScanning) {
      return;
    }

    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isStopping || !isScanning) {
        timer.cancel();
        return;
      }

      if (_isRequestInFlight) {
        debugPrint(
            "DEBUG (Overlay OCR): Previous request still running, skip tick.");
        return;
      }

      _isRequestInFlight = true;
      try {
        final result = await _apiService.scanScreen(reset: false);
        if (_isStopping || !mounted || !isScanning) {
          return;
        }
        final newText = result['extracted_text'];
        if (newText != null && newText.toString().isNotEmpty) {
          _addSessionText(newText.toString());
          debugPrint(
              "DEBUG (Overlay OCR): ${_compactForLog(newText.toString())}");
          FlutterOverlayWindow.shareData("TEXT:${newText.toString()}");
        } else {
          debugPrint("DEBUG (Overlay OCR): response was empty.");
        }
      } catch (e) {
        debugPrint("Overlay API error: $e");
        if (!_isStopping) {
          FlutterOverlayWindow.shareData("ERROR:${e.toString()}");
          await _stopScanning();
        }
      } finally {
        _isRequestInFlight = false;
      }
    });
  }

  Future<void> _stopScanning() async {
    if (_isStopping) {
      return;
    }

    _isStopping = true;
    try {
      _scanTimer?.cancel();
      _scanTimer = null;
      if (mounted) {
        setState(() => isScanning = false);
      }
      debugPrint(
          "DEBUG (Overlay): Scanning stopped, returning app to foreground.");

      if (_sessionLines.isNotEmpty) {
        final bulkText = _sessionLines.join('\n');
        debugPrint(
            "DEBUG (Overlay): Sending BULK_TEXT length=${bulkText.length}");
        FlutterOverlayWindow.shareData("BULK_TEXT:$bulkText");
      }

      FlutterOverlayWindow.shareData("SYNC_STOP_SCAN");

      await Future.delayed(const Duration(milliseconds: 250));
      await FlutterOverlayWindow.closeOverlay();
    } finally {
      // Allow a fresh start when the overlay is shown again.
      _isStopping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        // Allow dragging the overlay
        onPanUpdate: (details) {
          // Note: flutter_overlay_window provides dragging via config,
          // but if we want internal widget drag we can do it.
          // Better to use FlutterOverlayWindow.showOverlay(enableDrag: true)
        },
        onTap: () {
          debugPrint(
              "DEBUG (Overlay): Overlay button tapped! isScanning was $isScanning, isStopping=$_isStopping");
          if (isScanning) {
            _stopScanning();
          } else {
            _startScanning();
          }
        },
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isScanning
                ? Colors.redAccent.shade700
                : Colors.blueAccent.shade700,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 5,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Icon(
              isScanning ? Icons.stop_rounded : Icons.search_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
