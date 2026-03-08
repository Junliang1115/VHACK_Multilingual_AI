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
  Timer? _scanTimer;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == 'STOPPED' && mounted) {
        _stopScanning();
      }
    });
  }

  void _startScanning() {
    setState(() => isScanning = true);
    // Notify main app that scanning actually started on overlay side
    FlutterOverlayWindow.shareData("SYNC_START_SCAN");
    
    // First call to clear history
    _apiService.scanScreen(reset: true);
    
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final result = await _apiService.scanScreen(reset: false);
        final newText = result['extracted_text'];
        if (newText != null && newText.toString().isNotEmpty) {
           FlutterOverlayWindow.shareData("TEXT:${newText.toString()}");
        }
      } catch (e) {
        debugPrint("Overlay API error: $e");
      }
    });
  }

  Future<void> _stopScanning() async {
    _scanTimer?.cancel();
    if (mounted) {
      setState(() => isScanning = false);
    }
    FlutterOverlayWindow.shareData("SYNC_STOP_SCAN");
    
    FlutterOverlayWindow.closeOverlay();
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
          debugPrint("DEBUG (Overlay): Overlay button tapped! isScanning was $isScanning");
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
            color: isScanning ? Colors.redAccent.shade700 : Colors.blueAccent.shade700,
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
