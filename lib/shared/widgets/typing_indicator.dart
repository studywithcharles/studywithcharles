// lib/shared/widgets/typing_indicator.dart

import 'package:flutter/material.dart';

/// A widget that displays a "typing" animation with three bouncing dots.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (_, child) {
              final delay = index * 0.2;
              final t = (_controller.value - delay).clamp(0.0, 1.0);
              final y = -20 * (4 * t * (1 - t)); // Parabolic bounce
              return Transform.translate(offset: Offset(0, y), child: child);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.0),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.white54),
            ),
          );
        }),
      ),
    );
  }
}
