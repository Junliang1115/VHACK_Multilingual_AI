import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TopNavbar extends StatelessWidget {
  const TopNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.language_rounded, color: AppTheme.primaryBlue, size: isMobile ? 24 : 32),
          const SizedBox(width: 8),
          Text(
            isMobile ? 'GOV AI' : 'GOV TRANSLATE AI',
            style: GoogleFonts.outfit(
              textStyle: TextStyle(
                fontSize: isMobile ? 18 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.help_outline, size: 20),
              label: const Text('Guide'),
            ),
            const SizedBox(width: 16),
          ],
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: isMobile ? const EdgeInsets.symmetric(horizontal: 12) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 20),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  const Text('New Project'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
