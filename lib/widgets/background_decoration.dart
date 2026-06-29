import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BackgroundDecoration extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final String? backgroundImage;

  const BackgroundDecoration({
    Key? key,
    required this.child,
    this.baseColor,
    this.backgroundImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Background (uses provided baseColor or secondaryGreen)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (baseColor ?? AppColors.softWhiteBackground).withOpacity(0.98),
                (baseColor ?? AppColors.softWhiteBackground).withOpacity(0.95),
              ],
            ),
          ),
        ),

        // Optional background image (covers entire area)
        if (backgroundImage != null)
          Positioned.fill(
            child: Image.asset(
              backgroundImage!,
              fit: BoxFit.cover,
            ),
          ),

        // Subtle texture overlay to mimic board-game paper
        Positioned.fill(
          child: CustomPaint(
            painter: _GreenTexturePainter(),
          ),
        ),

        // Decorative Gradient Overlay 1 - Top Right (soft highlights)
        Positioned(
          top: -50,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondaryGreen.withOpacity(0.12),
                  AppColors.secondaryGreen.withOpacity(0.02),
                ],
              ),
            ),
          ),
        ),

        // Decorative Gradient Overlay 2 - Bottom Left (depth)
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryDarkGreen.withOpacity(0.08),
                  AppColors.primaryDarkGreen.withOpacity(0.01),
                ],
              ),
            ),
          ),
        ),

        // Decorative Gradient Overlay 3 - Top Left (cool tint)
        Positioned(
          top: 100,
          left: -120,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.essentialBlueAccent.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main Content
        child,
      ],
    );
  }
}

// Simple painter that lays down semi-random translucent speckles to create a paper-like texture.
class _GreenTexturePainter extends CustomPainter {
  final Random _rng = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw subtle darker blotches
    final blotchCount = ((size.width * size.height / 50000).clamp(30, 200)).toInt();
    for (var i = 0; i < blotchCount; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final radius = 0.6 + _rng.nextDouble() * 2.2;
      paint.color = Colors.black.withOpacity(0.012 + _rng.nextDouble() * 0.018);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Light scratches / streaks
    paint.color = Colors.white.withOpacity(0.01);
    for (var i = 0; i < 8; i++) {
      final sx = _rng.nextDouble() * size.width;
      final sy = _rng.nextDouble() * size.height;
      final ex = sx + (_rng.nextDouble() - 0.5) * size.width * 0.25;
      final ey = sy + (_rng.nextDouble() - 0.5) * size.height * 0.08;
      paint.strokeWidth = 0.6 + _rng.nextDouble() * 1.6;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
