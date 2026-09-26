import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/eco_ideas_service.dart';

class EcoIdeasDialog extends StatefulWidget {
  final String region;
  final int crisisLevel;
  final int crisisVariant;
  final String cardTitle;
  final String? cardAssetPath;

  const EcoIdeasDialog({
    Key? key,
    required this.region,
    required this.crisisLevel,
    required this.crisisVariant,
    required this.cardTitle,
    this.cardAssetPath,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String region,
    required int crisisLevel,
    required int crisisVariant,
    required String cardTitle,
    String? cardAssetPath,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EcoIdeasDialog(
        region: region,
        crisisLevel: crisisLevel,
        crisisVariant: crisisVariant,
        cardTitle: cardTitle,
        cardAssetPath: cardAssetPath,
      ),
    );
  }

  @override
  State<EcoIdeasDialog> createState() => _EcoIdeasDialogState();
}

class _EcoIdeasDialogState extends State<EcoIdeasDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isSubmitting = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitIdea() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ketik ide solusimu terlebih dahulu ya!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await EcoIdeasService.instance.saveIdea(
        cardTitle: widget.cardTitle,
        cardAssetPath: widget.cardAssetPath,
        region: widget.region,
        crisisLevel: widget.crisisLevel,
        solutionText: text,
      );
    } catch (_) {}

    if (!mounted) return;

    // Show celebration popup
    await _showCelebrationDialog();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showCelebrationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5C3D1E), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌟 🌍 🌟', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  'GREAT JOB, ECO HERO!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vt323(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ide solusimu sangat hebat dan telah disimpan ke profilmu!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: const Color(0xFF4E342E),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81C784),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      'LANJUTKAN GAME',
                      style: GoogleFonts.vt323(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(size.width * 0.82, 520.0);
    // The image aspect ratio is roughly 588 x 338 → ~1.74:1
    final dialogHeight = dialogWidth / 1.74;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Background Scroll Image
              Positioned.fill(
                child: Image.asset(
                  'assets/Element Eco Avenger/map/image-removebg-preview (27).png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // 2. Close / Skip button (top-right)
              Positioned(
                top: 4,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF5C3D1E), width: 2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF5C3D1E),
                    ),
                  ),
                ),
              ),




              // 4. Text Input Field on the scroll area
              Positioned(
                top: dialogHeight * 0.32,
                left: dialogWidth * 0.14,
                right: dialogWidth * 0.14,
                bottom: dialogHeight * 0.24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: 4,
                    autofocus: true,
                    style: GoogleFonts.vt323(
                      fontSize: (dialogHeight * 0.065).clamp(16.0, 20.0),
                      color: const Color(0xFF3E2723),
                      height: 1.25,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ketik ide solusimu untuk mengatasi krisis ini...',
                      hintStyle: GoogleFonts.vt323(
                        fontSize: (dialogHeight * 0.060).clamp(15.0, 18.0),
                        color: const Color(0xFF8D6E63).withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Submit Button overlay — positioned over the "Submit" graphic
              Positioned(
                bottom: dialogHeight * 0.02,
                left: dialogWidth * 0.30,
                right: dialogWidth * 0.30,
                height: dialogHeight * 0.18,
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _submitIdea,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseCtrl.value * 0.04);
                        return Transform.scale(
                          scale: _isSubmitting ? 0.95 : scale,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isSubmitting
                                  ? Colors.black.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _isSubmitting
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF5C3D1E),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
