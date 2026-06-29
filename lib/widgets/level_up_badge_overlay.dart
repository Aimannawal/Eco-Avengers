import 'package:flutter/material.dart';

class LevelUpBadgeOverlay extends StatefulWidget {
  final String badgeType; // 'climate', 'energy', 'ecology'
  final int level; // 1 = Icon Token, 2 = Icon Token, 3 = Master Token
  final double size;
  final bool glowing;

  const LevelUpBadgeOverlay({
    Key? key,
    required this.badgeType,
    this.level = 1,
    this.size = 90,
    this.glowing = false,
  }) : super(key: key);

  @override
  State<LevelUpBadgeOverlay> createState() => _LevelUpBadgeOverlayState();
}

class _LevelUpBadgeOverlayState extends State<LevelUpBadgeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  String _getBadgeAsset() {
    // Level 3 uses Master Token, levels 1-2 use Icon Token
    final isMaster = widget.level >= 3;
    final prefix = isMaster
        ? 'Professional Master Token'
        : 'Professional Icon Token';

    switch (widget.badgeType.toLowerCase()) {
      case 'climate':
      case 'climate engineer':
      case 'climate engineering':
        return 'assets/token/$prefix-Climate Engineering.png';
      case 'energy':
      case 'energy scientist':
      case 'energy science':
        return 'assets/token/$prefix-Energy Science.png';
      case 'ecology':
      case 'environment':
      case 'environmental ecologist':
      case 'environmental ecology':
        return 'assets/token/$prefix-Environmental Ecology.png';
      default:
        return 'assets/token/$prefix-Climate Engineering.png';
    }
  }

  Color _getBadgeGlowColor() {
    switch (widget.badgeType.toLowerCase()) {
      case 'climate':
      case 'climate engineer':
      case 'climate engineering':
        return const Color(0xFF1F7A7E); // Teal
      case 'energy':
      case 'energy scientist':
      case 'energy science':
        return const Color(0xFFD4A574); // Gold
      case 'ecology':
      case 'environment':
      case 'environmental ecologist':
      case 'environmental ecology':
        return const Color(0xFF8FBC8F); // Green
      default:
        return const Color(0xFF1F7A7E);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.glowing) {
      _glowController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this,
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
      );
    } else {
      _glowAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    if (widget.glowing) {
      _glowController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeGlowColor();
    final assetPath = _getBadgeAsset();
    final isMaster = widget.level >= 3;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.glowing
                ? [
                    // Outer glow - strong
                    BoxShadow(
                      color: badgeColor.withOpacity(_glowAnimation.value * 0.8),
                      blurRadius: 30 * _glowAnimation.value,
                      spreadRadius: 10 * _glowAnimation.value,
                    ),
                    // Inner glow - medium
                    BoxShadow(
                      color: badgeColor.withOpacity(_glowAnimation.value * 0.5),
                      blurRadius: 15 * _glowAnimation.value,
                      spreadRadius: 4 * _glowAnimation.value,
                    ),
                    // Base shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: isMaster
              ? OverflowBox(
                  maxWidth:
                      widget.size *
                      1.02, // Scale width up by just 2% for pixel-perfect match
                  maxHeight: widget.size * 1.6,
                  minWidth: widget.size * 1.02,
                  minHeight: widget.size * 1.6,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      -widget.size * 0.15,
                    ), // Shifted up even more to perfectly align centers vertically
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.shield,
                          color: badgeColor,
                          size: widget.size * 0.6,
                        );
                      },
                    ),
                  ),
                )
              : Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.shield,
                        color: badgeColor,
                        size: widget.size * 0.6,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
