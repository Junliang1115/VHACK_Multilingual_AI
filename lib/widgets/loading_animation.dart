import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProcessingAnimation extends StatefulWidget {
  const ProcessingAnimation({super.key});

  @override
  State<ProcessingAnimation> createState() => _ProcessingAnimationState();
}

class _ProcessingAnimationState extends State<ProcessingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _animation,
            child: const Icon(
              Icons.auto_awesome,
              size: 48,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'AI is analyzing and translating...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}
