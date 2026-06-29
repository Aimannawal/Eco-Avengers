import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BadgeShowcaseDialog extends StatefulWidget {
  const BadgeShowcaseDialog({Key? key}) : super(key: key);

  @override
  State<BadgeShowcaseDialog> createState() => _BadgeShowcaseDialogState();
}

class _BadgeShowcaseDialogState extends State<BadgeShowcaseDialog>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.pureWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Badges - Glowing Test',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primaryDarkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Grid of badges
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildBadge(
                          'Climate\nEngineering',
                          const Color(0xFF1F7A7E),
                          'assets/token/Professional Master Token-Climate Engineering.png',
                        ),
                        _buildBadge(
                          'Energy\nScience',
                          const Color(0xFFD4A574),
                          'assets/token/Professional Master Token-Energy Science.png',
                        ),
                        _buildBadge(
                          'Environmental\nEcology',
                          const Color(0xFF8FBC8F),
                          'assets/token/Professional Master Token-Environmental Ecology.png',
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Info text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Badges are glowing with animations. Check if positioning is precise for level-up views.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.black.withOpacity(0.6),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color badgeColor, String assetPath) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Outer glow
              BoxShadow(
                color: badgeColor.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 20 * _glowAnimation.value,
                spreadRadius: 5 * _glowAnimation.value,
              ),
              // Inner glow
              BoxShadow(
                color: badgeColor.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 10 * _glowAnimation.value,
                spreadRadius: 2 * _glowAnimation.value,
              ),
              // Shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: badgeColor.withOpacity(_glowAnimation.value),
                width: 2 * _glowAnimation.value,
              ),
            ),
            child: ClipOval(
              child: Stack(
                children: [
                  // Badge background
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          badgeColor.withOpacity(0.1),
                          badgeColor.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                  // Badge image
                  Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: badgeColor.withOpacity(0.2),
                        child: Center(
                          child: Icon(
                            Icons.shield,
                            color: badgeColor,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                  // Shine effect
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3 * _glowAnimation.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
