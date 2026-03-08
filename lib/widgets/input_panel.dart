import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';

class InputPanel extends StatefulWidget {
  const InputPanel({super.key});

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize controller with existing text if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TranslationProvider>(context, listen: false);
      _controller.text = provider.sourceText;
      _controller.addListener(() {
        provider.setSourceText(_controller.text);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<TranslationProvider>(context, listen: false);
      if (provider.isScanning) {
        debugPrint("DEBUG (Main): App resumed manually, auto-stopping overlay scan");
        provider.stopContinuousScan();
        FlutterOverlayWindow.closeOverlay();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final translationProvider = Provider.of<TranslationProvider>(context);

    // Update controller text if provider's sourceText changed outside (like from OCR)
    if (_controller.text != translationProvider.sourceText) {
      final newText = translationProvider.sourceText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_controller.text != newText) {
          _controller.text = newText;
          // Move cursor to end
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      });
    }

    // Show error message if any
    if (translationProvider.errorMessage.isNotEmpty) {
      final errorMessage = translationProvider.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clear error in provider BEFORE showing so it doesn't loop
        translationProvider.clearError();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK', 
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      });
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Source Content',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.upload_file_outlined,
                      label: isMobile ? 'Doc' : 'Upload Doc',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: translationProvider.isScanning 
                          ? Icons.stop_circle_outlined 
                          : (translationProvider.isLoading 
                              ? Icons.hourglass_empty 
                              : Icons.screen_search_desktop_outlined),
                      label: translationProvider.isScanning
                          ? 'Stop Scanning'
                          : (translationProvider.isLoading && _controller.text == translationProvider.sourceText
                              ? 'Scanning...' 
                              : (isMobile ? 'Capture' : 'Screen Capture')),
                      color: translationProvider.isScanning ? Colors.red : null,
                      onPressed: () async {
                        if (translationProvider.isScanning) {
                          debugPrint("DEBUG: Stop Scanning button pressed!");
                          translationProvider.stopContinuousScan();
                          await FlutterOverlayWindow.closeOverlay();
                        } else {
                          debugPrint("DEBUG: Start Continuous Scan triggered via overlay!");
                          
                          bool status = await FlutterOverlayWindow.isPermissionGranted();
                          if (!status) {
                            // Can't use await if requestPermission returns bool directly but doc says Future<bool?>
                            final permissionStatus = await FlutterOverlayWindow.requestPermission();
                            status = permissionStatus ?? false;
                          }
                          
                          if (status) {
                            final isActive = await FlutterOverlayWindow.isActive();
                            if (!isActive) {
                              await FlutterOverlayWindow.showOverlay(
                                enableDrag: true,
                                flag: OverlayFlag.defaultFlag,
                                alignment: OverlayAlignment.centerRight,
                                width: 100,
                                height: 100,
                              );
                            }
                            const MethodChannel('com.example.gov_translator/app_channel').invokeMethod('moveToBackground');
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please grant "Display over other apps" permission to enable the hovering icon.'), 
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Paste text or upload a document to begin...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(isMobile ? 12 : 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: translationProvider.isLoading 
                  ? null 
                  : () => translationProvider.translateText(_controller.text),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(translationProvider.isLoading ? 'Processing...' : 'Translate Now'),
                    const SizedBox(width: 8),
                    translationProvider.isLoading 
                      ? const SizedBox(
                          width: 18, 
                          height: 18, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? AppTheme.primaryBlue,
        side: BorderSide(color: color?.withOpacity(0.3) ?? Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
