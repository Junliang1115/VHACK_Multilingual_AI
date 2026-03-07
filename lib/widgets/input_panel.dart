import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

class InputPanel extends StatefulWidget {
  const InputPanel({super.key});

  @override
  State<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends State<InputPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final translationProvider = Provider.of<TranslationProvider>(context);

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
                      icon: Icons.screen_search_desktop_outlined,
                      label: isMobile ? 'Capture' : 'Screen Capture',
                      onPressed: () {},
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
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
