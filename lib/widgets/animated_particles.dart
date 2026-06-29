import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedParticles extends StatefulWidget {
  final Color particleColor;
  final int particleCount;
  final Duration animationDuration;

  const AnimatedParticles({
    Key? key,
    this.particleColor = const Color(0xFF67A596),
    this.particleCount = 30,
    this.animationDuration = const Duration(seconds: 20),
  }) : super(key: key);

  @override
  State<AnimatedParticles> createState() => _AnimatedParticlesState();
}

class _AnimatedParticlesState extends State<AnimatedParticles>
    with TickerProviderStateMixin {
  late List<_Particle> particles;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat();
  }

  void _initializeParticles() {
    final random = math.Random();
    particles = List.generate(
      widget.particleCount,
      (index) => _Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        duration: Duration(
          seconds: random.nextInt(20) + 15,
        ),
        delay: random.nextDouble() * 5,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlesPainter(
        particles: particles,
        animation: _controller,
        particleColor: widget.particleColor,
      ),
      size: Size.infinite,
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final Duration duration;
  final double delay;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.duration,
    required this.delay,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;
  final Color particleColor;

  _ParticlesPainter({
    required this.particles,
    required this.animation,
    required this.particleColor,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = particleColor
      ..style = PaintingStyle.fill;

    for (final particle in particles) {
      final adjustedAnimation = ((animation.value * 1000 + particle.delay * 100) %
              (particle.duration.inMilliseconds)) /
          particle.duration.inMilliseconds;

      final yOffset = adjustedAnimation * size.height;
      final opacity = (1 - adjustedAnimation) * 0.4;

      paint.color = particleColor.withOpacity(opacity);
      canvas.drawCircle(
        Offset(particle.x * size.width, yOffset),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}
