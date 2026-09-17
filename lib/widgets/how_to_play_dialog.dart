import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

const _tutorialUrl = 'https://drive.google.com/drive/folders/18EefL9mSZ4pz9ys0KcBkWazvS4MR3niS';

Future<void> showHowToPlayDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'HowToPlay',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, a1, a2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = Curves.easeOut.transform(animation.value);
      final scale = 0.92 + (0.08 * curved);
      final opacity = curved;

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5 * curved, sigmaY: 5 * curved),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: const _HowToPlayCard(),
          ),
        ),
      );
    },
  );
}

class _HowToPlayCard extends StatefulWidget {
  const _HowToPlayCard({Key? key}) : super(key: key);

  @override
  State<_HowToPlayCard> createState() => _HowToPlayCardState();
}

class _HowToPlayCardState extends State<_HowToPlayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxWidth = w < 480 ? w * 0.86 : 340.0;

    return Center(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = (_floatController.value * 2 - 1) * 4;
          return Transform.translate(
            offset: Offset(0, t),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: maxWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF111111),
                width: 3,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Video preview placeholder
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFF75B9E7),
                        border: Border.all(color: const Color(0xFF111111), width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF5AB6F5),
                                    Color(0xFF3898EC),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFDB72),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF111111), width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 34,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'HOW TO PLAY',
                    style: GoogleFonts.fredoka(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                      letterSpacing: 0.8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Learn the rules, strategies, and how to save the future of Earth in Eco Avenger.',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            Navigator.of(context).pop();
                            final uri = Uri.parse(_tutorialUrl);
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDB72),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: const Color(0xFF111111), width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(0, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill_rounded, size: 18, color: Color(0xFF111111)),
                                const SizedBox(width: 6),
                                Text(
                                  'Watch',
                                  style: GoogleFonts.fredoka(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111111),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: const Color(0xFF111111), width: 2.5),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.fredoka(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111),
                              ),
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
        ),
      ),
    );
  }
}

