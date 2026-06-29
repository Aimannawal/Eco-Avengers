import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

const _tutorialUrl = 'https://youtu.be/AdUoc-nSB94?si=x7gZ0YVhdNdxvCiT';

Future<void> showHowToPlayDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'HowToPlay',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, a1, a2) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = Curves.easeOut.transform(animation.value);
      final scale = 0.92 + (0.08 * curved);
      final opacity = curved;

      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * curved, sigmaY: 6 * curved),
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
    final maxWidth = w < 480 ? w * 0.82 : 320.0;

    return Center(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = (_floatController.value * 2 - 1) * 6; // -6..6 px
          return Transform.translate(
            offset: Offset(0, t),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: maxWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.pureWhite.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDarkGreen.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.secondaryGreen.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 130,
                      color: AppColors.primaryDarkGreen.withOpacity(0.06),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryDarkGreen.withOpacity(0.06),
                                  AppColors.pureWhite.withOpacity(0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite.withOpacity(0.06),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 28,
                              color: AppColors.primaryDarkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'How To Play Eco Avenger',
                  style: AppTheme.titleMedium.copyWith(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Learn the rules, strategies, and how to save the future of Earth.',
                  style: AppTheme.subtitleSmall.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close popup then open YouTube externally
                          Navigator.of(context).pop();
                          final uri = Uri.parse(_tutorialUrl);
                          try {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryGreen,
                          foregroundColor: AppColors.pureWhite,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                        child: Text('Watch', style: AppTheme.buttonText.copyWith(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDarkGreen,
                          side: BorderSide(color: AppColors.primaryDarkGreen.withOpacity(0.12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('Close', style: AppTheme.buttonText.copyWith(color: AppColors.primaryDarkGreen, fontSize: 12)),
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
