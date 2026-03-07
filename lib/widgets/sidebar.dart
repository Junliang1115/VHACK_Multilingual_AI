import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HistorySidebar extends StatelessWidget {
  const HistorySidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Text(
                  'Translation History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: 10,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _HistoryItem(
                  title: 'Document $index.pdf',
                  subtitle: 'Translated to Malay (Kedah Dialect)',
                  time: '${index + 1}h ago',
                  isActive: index == 0,
                );
              },
            ),
          ),
          const _SidebarFooter(),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isActive;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    required this.time,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryBlue.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined, size: 20, color: AppTheme.textLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppTheme.textLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.primaryBlue,
            radius: 18,
            child: Text('JD', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('John Doe', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Gov. Official', style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}
