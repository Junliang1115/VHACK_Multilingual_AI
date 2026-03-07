import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';

class OutputPanel extends StatelessWidget {
  const OutputPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TranslationProvider>(context);

    if (provider.isLoading && provider.translatedText.isEmpty) {
      return const _EmptyState(showLoading: true);
    }

    if (provider.errorMessage.isNotEmpty) {
      return _ErrorState(message: provider.errorMessage);
    }

    if (provider.translatedText.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: _ResultCard(
            title: 'AI Summary',
            icon: Icons.summarize_outlined,
            content: provider.summary,
            color: Colors.blue.shade50,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          flex: 3,
          child: _ResultCard(
            title: 'Dialect Translation',
            icon: Icons.translate,
            isTranslation: true,
            content: provider.translatedText,
            color: Colors.teal.shade50,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showLoading;
  const _EmptyState({this.showLoading = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showLoading ? Icons.auto_awesome : Icons.translate_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            showLoading ? 'AI is working...' : 'Results will appear here',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Error: $message',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          TextButton(
            onPressed: () => Provider.of<TranslationProvider>(context, listen: false).translateText(""),
            child: const Text('Clear'),
          )
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final Color color;
  final bool isTranslation;

  const _ResultCard({
    required this.title,
    required this.icon,
    required this.content,
    required this.color,
    this.isTranslation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (isTranslation)
                  Consumer<TranslationProvider>(
                    builder: (context, provider, _) => DropdownButton<String>(
                      value: provider.currentDialect,
                      underline: const SizedBox(),
                      items: ['Kedah', 'Kelantan', 'Terengganu', 'Standard']
                          .map((s) => DropdownMenuItem(value: s, child: Text('$s Dialect')))
                          .toList(),
                      onChanged: (v) => provider.setDialect(v!),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.copy_rounded, size: 20)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined, size: 20)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
