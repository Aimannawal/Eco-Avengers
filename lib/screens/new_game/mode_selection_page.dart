import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'character_selection_page.dart';
import '../multiplayer/lobby_screen.dart';

class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({Key? key}) : super(key: key);

  /// Public agar bisa diakses dari WaitingRoomScreen & LobbyScreen
  static const List<CharacterOption> characterOptions = [
    CharacterOption(
      title: 'Environmental Activist',
      description: 'Move two spaces forward at once during your turn.',
      assetPath:
          'assets/character/Character Sheet-Environmental Activist.png',
      accentColor: Color(0xFF38A3A5),
    ),
    CharacterOption(
      title: 'Policymaker',
      description:
          'Adds 1 to the first derived dice value for other players in range.',
      assetPath: 'assets/character/Character Sheet-Policymaker.png',
      accentColor: Color(0xFFB07D54),
    ),
    CharacterOption(
      title: 'Climate Engineer',
      description: 'Decreases Climate Resilience difficulty by 1.',
      assetPath:
          'assets/character/Character Sheet-Climate Engineer.png',
      accentColor: Color(0xFFF06292),
    ),
    CharacterOption(
      title: 'Ecologist',
      description: 'Decreases Environmental Degradation difficulty by 1.',
      assetPath: 'assets/character/Character Sheet-Ecologist.png',
      accentColor: Color(0xFFED9B3B),
    ),
    CharacterOption(
      title: 'Energy Scientist',
      description: 'Decreases Energy Crisis difficulty by 1.',
      assetPath:
          'assets/character/Character Sheet-Energy Scientist.png',
      accentColor: Color(0xFF4F7DBA),
    ),
  ];

  static const Color _buttonColor = Color(0xFFA5C18A); // Original light green button tone
  static const Color _borderColor = Color(0xFF111111);
  static const Color _feltColor = Color(0xFF6A9073); // Original green board tone

  void _selectDifficulty(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CharacterSelectionPage(
          difficulty: difficulty,
          characters: characterOptions,
        ),
      ),
    );
  }

  void _selectMultiplayer(BuildContext context, String difficulty) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(difficulty: difficulty),
      ),
    );
  }

  Widget _buildDifficultyButtons({
    required BuildContext context,
    required double buttonWidth,
    required double buttonHeight,
    required double gap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeChoiceButton(
          label: 'Easy',
          width: buttonWidth,
          height: buttonHeight,
          onTap: () => _selectDifficulty(context, 'easy'),
          buttonColor: _buttonColor,
          borderColor: _borderColor,
        ),
        SizedBox(height: gap),
        _ModeChoiceButton(
          label: 'Medium',
          width: buttonWidth,
          height: buttonHeight,
          onTap: () => _selectDifficulty(context, 'normal'),
          buttonColor: _buttonColor,
          borderColor: _borderColor,
        ),
        SizedBox(height: gap),
        _ModeChoiceButton(
          label: 'Hard',
          width: buttonWidth,
          height: buttonHeight,
          onTap: () => _selectDifficulty(context, 'hard'),
          buttonColor: _buttonColor,
          borderColor: _borderColor,
        ),
        SizedBox(height: gap * 1.5),
        // ── Divider ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: buttonWidth * 0.3,
              child: Divider(color: Colors.white.withOpacity(0.35), thickness: 1.2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'ATAU',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              width: buttonWidth * 0.3,
              child: Divider(color: Colors.white.withOpacity(0.35), thickness: 1.2),
            ),
          ],
        ),
        SizedBox(height: gap),
        // ── Multiplayer button ──
        _ModeChoiceButton(
          label: '🌐  MULTIPLAYER',
          width: buttonWidth,
          height: buttonHeight,
          onTap: () => _selectMultiplayer(context, 'normal'),
          buttonColor: const Color(0xFF4F9DC4),
          borderColor: _borderColor,
          textColor: Colors.white,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Wood background table
          Image.asset(
            'assets/background/kayu.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.12)),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Since app is landscape-only, we mainly care about height for mobile vs tablet
                final isCompactHeight = constraints.maxHeight < 500;
                
                final boardWidth = math.min(constraints.maxWidth * 0.85, 800.0);
                final boardHeight = math.min(constraints.maxHeight * 0.85, 460.0);

                final buttonWidth = isCompactHeight ? boardWidth * 0.35 : 260.0;
                final buttonHeight = isCompactHeight ? 42.0 : 56.0;
                final gap = isCompactHeight ? 12.0 : 20.0;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // --- SCATTERED DECORATIONS ON THE TABLE (UNDER THE BOARD) ---
                    
                    // 1. Top-Left: Scattered cards sticking out
                    Positioned(
                      left: isCompactHeight ? constraints.maxWidth * 0.02 : 10,
                      top: isCompactHeight ? constraints.maxHeight * 0.05 : 20,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: Container(
                          width: isCompactHeight ? 60 : 90,
                          height: isCompactHeight ? 90 : 130,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(1, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/action_card/Action Cards-Back.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    Positioned(
                      left: isCompactHeight ? constraints.maxWidth * 0.01 : -10,
                      top: isCompactHeight ? constraints.maxHeight * 0.12 : 80,
                      child: Transform.rotate(
                        angle: 0.15,
                        child: Container(
                          width: isCompactHeight ? 60 : 85,
                          height: isCompactHeight ? 85 : 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(1, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/eco_crisis_card/Eco Crisis Card-Europe-Back.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. Bottom-Right: Character sheet sticking out
                    Positioned(
                      right: isCompactHeight ? constraints.maxWidth * 0.02 : 10,
                      bottom: isCompactHeight ? constraints.maxHeight * 0.05 : 10,
                      child: Transform.rotate(
                        angle: 0.12,
                        child: Container(
                          width: isCompactHeight ? 80 : 120,
                          height: isCompactHeight ? 110 : 160,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/character/Character Sheet-Policymaker.png',
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Scattered Tokens
                    // Positioned(
                    //   right: isCompactHeight ? constraints.maxWidth * 0.08 : 60,
                    //   bottom: isCompactHeight ? constraints.maxHeight * 0.02 : 5,
                    //   child: Transform.rotate(
                    //     angle: -0.2,
                    //     child: SizedBox(
                    //       width: isCompactHeight ? 28 : 40,
                    //       height: isCompactHeight ? 28 : 40,
                    //       child: Image.asset(
                    //         'assets/token/sustainable.png',
                    //         fit: BoxFit.contain,
                    //       ),
                    //     ),
                    //   ),
                    // ),

                    Positioned(
                      left: isCompactHeight ? constraints.maxWidth * 0.10 : 60,
                      top: isCompactHeight ? constraints.maxHeight * 0.02 : 5,
                      child: Transform.rotate(
                        angle: 0.4,
                        child: SizedBox(
                          width: isCompactHeight ? 26 : 38,
                          height: isCompactHeight ? 26 : 38,
                          child: Image.asset(
                            'assets/token/crisis.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    
                    // --- MAIN GREEN FELT BOARD ---
                    Center(
                      child: SizedBox(
                        width: boardWidth,
                        height: boardHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Felt board panel container
                            Container(
                              decoration: BoxDecoration(
                                color: _feltColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _borderColor,
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              child: Row(
                                      children: [
                                        // Left side: Action Card
                                        Expanded(
                                          flex: 4,
                                          child: Center(
                                            child: _buildActionCard(isCompactHeight),
                                          ),
                                        ),
                                        // Right side: Mode Buttons
                                        Expanded(
                                          flex: 6,
                                          child: Center(
                                            child: SingleChildScrollView(
                                              physics: const BouncingScrollPhysics(),
                                              child: _buildDifficultyButtons(
                                                context: context,
                                                buttonWidth: buttonWidth,
                                                buttonHeight: buttonHeight,
                                                gap: gap,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            
                            // Circular Back Button overlay (top-left) - Replaces Bell Button
                            Positioned(
                              left: -14,
                              top: -14,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    width: isCompactHeight ? 44 : 64,
                                    height: isCompactHeight ? 44 : 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _feltColor,
                                      border: Border.all(
                                        color: _borderColor,
                                        width: 3.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: isCompactHeight ? 24 : 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(bool isCompactHeight) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main action card image
        Transform.rotate(
          angle: -0.05,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(2, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/action_card/3.png',
                fit: BoxFit.contain,
                height: isCompactHeight ? 180 : 260,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: isCompactHeight ? 120 : 180,
                    height: isCompactHeight ? 180 : 260,
                    color: Colors.white.withOpacity(0.9),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'Card 3 Not Found',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Overlapping blue "+1" difficulty token (top-right of card)
        Positioned(
          right: -10,
          top: -15,
          child: Transform.rotate(
            angle: 0.15,
            child: SizedBox(
              width: isCompactHeight ? 32 : 44,
              height: isCompactHeight ? 32 : 44,
              child: Image.asset(
                'assets/token/Difficulty+1 Token.png',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeChoiceButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final VoidCallback onTap;
  final Color buttonColor;
  final Color borderColor;
  final Color textColor;

  const _ModeChoiceButton({
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
    required this.buttonColor,
    required this.borderColor,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(51),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(51),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: textColor,
              fontSize: height < 50 ? 18 : 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
