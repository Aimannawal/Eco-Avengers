import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class MenuButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;
  final Duration animationDuration;
  final double height;
  final double fontSize;
  final double iconSize;

  const MenuButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.icon,
    this.animationDuration = const Duration(milliseconds: 300),
    this.height = 48,
    this.fontSize = 13,
    this.iconSize = 18,
  }) : super(key: key);

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    setState(() {
      _isHovering = isHovering;
    });

    if (isHovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onTap() {
    // Button press animation
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: _onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              height: widget.height,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.isPrimary
                    ? LinearGradient(
                        colors: [
                          AppColors.primaryDarkGreen,
                          AppColors.secondaryGreen,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !widget.isPrimary ? AppColors.softGray : null,
                boxShadow: [
                  BoxShadow(
                    color: widget.isPrimary
                        ? AppColors.primaryDarkGreen.withOpacity(0.3)
                        : AppColors.deepBlack.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  if (_isHovering)
                    BoxShadow(
                      color: widget.isPrimary
                          ? AppColors.primaryDarkGreen.withOpacity(0.4)
                          : AppColors.deepBlack.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Glassmorphism effect
                  if (widget.isPrimary)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.pureWhite.withOpacity(0.1),
                                  AppColors.pureWhite.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Button Content
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: widget.isPrimary
                                ? AppColors.pureWhite
                                : AppColors.primaryDarkGreen,
                            size: widget.iconSize,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: AppTheme.buttonText.copyWith(
                            color: widget.isPrimary
                                ? AppColors.pureWhite
                                : AppColors.primaryDarkGreen,
                            fontSize: widget.fontSize,
                          ),
                        ),
                      ],
                    ),
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
