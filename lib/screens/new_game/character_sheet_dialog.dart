import 'package:flutter/material.dart';
import '../../widgets/level_up_badge_overlay.dart';

class CharacterSheetDialog extends StatefulWidget {
  final String characterName;
  final String assetPath;
  final Color accentColor;
  final String ability;
  /// Badge unlock levels: 'energy'/'ecology'/'climate' → 0..3 (0 = hidden)
  final Map<String, int> unlockedBadgeLevels;

  const CharacterSheetDialog({
    Key? key,
    required this.characterName,
    required this.assetPath,
    required this.accentColor,
    required this.ability,
    this.unlockedBadgeLevels = const {'energy': 0, 'ecology': 0, 'climate': 0},
  }) : super(key: key);

  @override
  State<CharacterSheetDialog> createState() => _CharacterSheetDialogState();
}

class _CharacterSheetDialogState extends State<CharacterSheetDialog>
    with TickerProviderStateMixin {
  // One AnimationController per badge slot (3 rows × 3 cols = 9 slots)
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      9,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 450),
        vsync: this,
      ),
    );
    _scaleAnimations = _controllers
        .map(
          (c) => CurvedAnimation(parent: c, curve: Curves.elasticOut),
        )
        .toList();

    // Trigger animations for badges that are already unlocked on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerUnlockedBadges());
  }

  void _triggerUnlockedBadges() {
    const rowTypes = ['energy', 'ecology', 'climate'];
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final idx = row * 3 + col;
        final level = col + 1; // col 0 = level 1, col 1 = level 2, col 2 = level 3
        final unlocked = widget.unlockedBadgeLevels[rowTypes[row]] ?? 0;
        if (unlocked >= level) {
          // Stagger each badge slightly for a nicer reveal
          Future.delayed(Duration(milliseconds: 80 * idx), () {
            if (mounted) _controllers[idx].forward();
          });
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build character sheet path from character name
    final charSheetPath =
        'assets/character_sheet/Character Sheet-${widget.characterName}.png';

    // Badge type for each row on the character sheet:
    // Row 0 = Energy Science
    // Row 1 = Environmental Ecology
    // Row 2 = Climate Engineering
    const rowTypes = ['energy', 'ecology', 'climate'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Character sheet image
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    charSheetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.white,
                        child: const Center(
                          child: Text('Character sheet not found'),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Badge overlay layer — matches image size via Positioned.fill
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, imgConstraints) {
                    final w = imgConstraints.maxWidth;
                    final h = imgConstraints.maxHeight;

                    // Badge size scales with image height
                    final badgeSize = h * 0.165;

                    // Column centers
                    final colCenters = [w * 0.609, w * 0.745, w * 0.863];

                    // Row centers
                    final rowCenters = [h * 0.345, h * 0.56, h * 0.775];

                    // Build all 9 badge positions
                    final List<Widget> badges = [];
                    for (int row = 0; row < 3; row++) {
                      for (int col = 0; col < 3; col++) {
                        final idx = row * 3 + col;
                        final level = col + 1;
                        final unlocked =
                            widget.unlockedBadgeLevels[rowTypes[row]] ?? 0;
                        final isUnlocked = unlocked >= level;

                        // Fine-tune col 3 (Master Token) position
                        final double tweakTop = col == 2 ? -h * 0.015 : 0;

                        badges.add(
                          Positioned(
                            left: colCenters[col] - (badgeSize / 2),
                            top: rowCenters[row] - (badgeSize / 2) + tweakTop,
                            child: isUnlocked
                                ? ScaleTransition(
                                    scale: _scaleAnimations[idx],
                                    child: LevelUpBadgeOverlay(
                                      badgeType: rowTypes[row],
                                      level: level,
                                      size: badgeSize,
                                      glowing: false,
                                    ),
                                  )
                                : const SizedBox.shrink(), // hidden when locked
                          ),
                        );
                      }
                    }

                    return Stack(clipBehavior: Clip.none, children: badges);
                  },
                ),
              ),
              // Close button (top-right)
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
          );
        },
      ),
    );
  }
}
