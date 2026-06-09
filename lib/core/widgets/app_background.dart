import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF090E1A),
                      Color(0xFF10162A),
                      Color(0xFF08131C),
                    ]
                  : const [
                      Color(0xFFF7F8FF),
                      Color(0xFFEEF7FF),
                      Color(0xFFF8F4FF),
                    ],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _Glow(
            color: const Color(
              0xFF4F46E5,
            ).withValues(alpha: dark ? 0.22 : 0.12),
            size: 250,
          ),
        ),
        Positioned(
          bottom: 80,
          left: -100,
          child: _Glow(
            color: const Color(0xFF06B6D4).withValues(alpha: dark ? 0.16 : 0.1),
            size: 280,
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
