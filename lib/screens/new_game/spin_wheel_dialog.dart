import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class SpinWheelDialog extends StatefulWidget {
  final Function(String)? onResult;
  final String difficulty;

  const SpinWheelDialog({Key? key, this.onResult, this.difficulty = 'normal'})
    : super(key: key);

  @override
  State<SpinWheelDialog> createState() => _SpinWheelDialogState();
}

class _SpinWheelDialogState extends State<SpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late final List<String> _segments;
  static const Map<String, Color> _segmentColors = {
    '1': Color(0xFFA5C18A),
    '2': Color(0xFFA5C18A),
    '3': Color(0xFFA5C18A),
    '4': Color(0xFFA5C18A),
    'fail': Color(0xFFEB5757),
  };

  static const Color _buttonGreen = Color(0xFFA5C18A);
  static const Color _buttonBorder = Color(0xFF111111);
  static const String _failDisplayValue = '-1';

  late final AnimationController _controller;
  late final Animation<double> _rotation;
  final math.Random _random = math.Random();

  // Menggunakan sudut radian untuk akurasi posisi visual
  double _startAngle = 0.0;
  double _targetAngle = 0.0;

  int _selectedIndex = 0;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();

    _segments = _getSegmentsByDifficulty(widget.difficulty);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 2200,
      ), // Sedikit diperlama agar spin terasa halus
    );
    _rotation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  List<String> _getSegmentsByDifficulty(String difficulty) {

    switch (difficulty.toLowerCase()) {
      case 'easy':
        return ['1', '2', 'fail', '4', '3', 'fail'];
      case 'hard':
        return ['1', '2', 'fail', '3', '4', 'fail'];
      case 'normal':
      default:
        return ['1', '2', 'fail', '3', '4', 'fail'];
    }
  }

  List<Color> get _resolvedWheelColors {
    return _segments.map((segment) {
      return _segmentColors[segment] ?? AppColors.secondaryGreen;
    }).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_isSpinning) return;

    // 1. Pilih indeks segment secara acak terlebih dahulu
    final int randomIndex = _random.nextInt(_segments.length);

    // 2. Hitung sudut yang dibutuhkan agar segment tersebut pas berada di posisi atas (pointer)
    final double segmentAngle = 2 * math.pi / _segments.length;
    final double angleToCenter =
        (randomIndex * segmentAngle) + (segmentAngle / 2);
    final double exactTargetAngle = 2 * math.pi - angleToCenter;

    // 3. Berikan sedikit offset acak di dalam segment agar posisi jarum bervariasi (tidak kaku di tengah)
    final double randomOffset =
        (_random.nextDouble() - 0.5) * (segmentAngle * 0.6);

    // 4. Akumulasikan putaran (misal: 5 kali putaran penuh + sudut target)
    _startAngle = _targetAngle % (2 * math.pi); // Normalisasi sudut sebelumnya
    const int fullSpins = 5;
    _targetAngle =
        _startAngle +
        (fullSpins * 2 * math.pi) +
        (exactTargetAngle - _startAngle) +
        randomOffset;

    setState(() {
      _isSpinning = true;
      _selectedIndex = randomIndex;
    });

    _controller.reset();
    await _controller.forward();

    if (!mounted) return;
    setState(() {
      _isSpinning = false;
    });

    // 5. Panggil callback dengan hasil yang dipastikan SAMA dengan tampilan visual roda
    final result = _segments[_selectedIndex];
    
    // Auto-close spin wheel popup
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    widget.onResult?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wheelSize = math.min(size.width, size.height) * 0.40;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: math.min(320, size.width * 0.86),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Solve Global Issue',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDarkGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: wheelSize,
                      height: wheelSize,
                      child: AnimatedBuilder(
                        animation: _rotation,
                        builder: (context, child) {
                          // Interpolasi linear perubahan sudut dari posisi awal ke target akhir
                          final currentAngle =
                              _startAngle +
                              (_targetAngle - _startAngle) * _rotation.value;
                          return Transform.rotate(
                            angle: currentAngle,
                            child: child,
                          );
                        },
                        child: CustomPaint(
                          painter: _WheelPainter(
                            segments: _segments,
                            colors: _resolvedWheelColors,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(28, 18),
                      painter: _PointerPainter(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _spin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(51),
                          side: const BorderSide(
                            color: _buttonBorder,
                            width: 3,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Spin',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: _buttonGreen,
                        side: const BorderSide(color: _buttonBorder, width: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(51),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> segments;
  final List<Color> colors;

  _WheelPainter({required this.segments, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final segmentAngle = 2 * math.pi / segments.length;
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(0.9);

    for (var i = 0; i < segments.length; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + (i * segmentAngle),
        segmentAngle,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + (i * segmentAngle),
        segmentAngle,
        true,
        borderPaint,
      );

      final angle = -math.pi / 2 + (i * segmentAngle) + (segmentAngle / 2);
      final textOffset = Offset(
        center.dx + math.cos(angle) * radius * 0.58,
        center.dy + math.sin(angle) * radius * 0.58,
      );
      final label = segments[i] == 'fail' ? 'FAIL' : segments[i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      // Perbaikan di sini: langsung gunakan textOffset.dy
      canvas.translate(textOffset.dx, textOffset.dy);

      // Memutar text agar menghadap ke arah luar center secara rapi
      canvas.rotate(angle + math.pi / 2);

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      radius * 0.12,
      Paint()..color = Colors.white.withOpacity(0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E6B57);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(0.85);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
