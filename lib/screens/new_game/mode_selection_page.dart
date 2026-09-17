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


  // --- ASSETS ---
  static const String _bgPath = 'assets/Element Eco Avenger/Menu page/bg.png';
  static const String _grassPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_083830_0000.png';
  static const String _scrollPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085509_0000.png';
  static const String _bannerPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085604_0000.png';
  
  static const String _easyPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085529_0000.png';
  static const String _mediumPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085536_0000.png';
  static const String _hardPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085544_0000.png';
  static const String _multiplayerPath = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_085552_0000.png';

  Widget _buildImageButton(String assetPath, VoidCallback onTap, double width) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Image.asset(
          assetPath,
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Sky & Hills
          Image.asset(
            _bgPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),

          // 2. Scroll and Buttons (Centered)
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ensure the scroll fits within both width and height (scale reduced so it doesn't overflow)
                double scrollHeight = constraints.maxHeight * 0.6;
                double scrollWidth = scrollHeight * 1.4; // Scroll aspect ratio roughly 1.4:1
                
                if (scrollWidth > constraints.maxWidth * 0.75) {
                  scrollWidth = constraints.maxWidth * 0.75;
                  scrollHeight = scrollWidth / 1.4;
                }
                
                final double buttonWidth = scrollWidth * 0.45; // Made buttons smaller
                final double gap = scrollHeight * 0.025; // Smaller gap
                
                return SizedBox(
                  width: scrollWidth,
                  height: scrollHeight + (scrollHeight * 0.15), // Extra space for banner
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Scroll Background
                      Positioned(
                        top: scrollHeight * 0.15,
                        child: Image.asset(
                          _scrollPath,
                          width: scrollWidth,
                          height: scrollHeight,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      
                      // Banner and Buttons Column
                      Positioned(
                        top: scrollHeight * 0.08, // Start slightly lower so it overlaps nicely
                        left: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Banner
                            Image.asset(
                              _bannerPath,
                              width: scrollWidth * 0.55, // Made banner smaller
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            SizedBox(height: gap * 2.0),
                            
                            // Easy Button
                            _buildImageButton(
                              _easyPath,
                              () => _selectDifficulty(context, 'easy'),
                              buttonWidth,
                            ),
                            SizedBox(height: gap),
                            
                            // Medium Button
                            _buildImageButton(
                              _mediumPath,
                              () => _selectDifficulty(context, 'normal'),
                              buttonWidth,
                            ),
                            SizedBox(height: gap),
                            
                            // Hard Button
                            _buildImageButton(
                              _hardPath,
                              () => _selectDifficulty(context, 'hard'),
                              buttonWidth,
                            ),
                            SizedBox(height: gap),
                            
                            // Multiplayer Button
                            _buildImageButton(
                              _multiplayerPath,
                              () => _selectMultiplayer(context, 'normal'),
                              buttonWidth,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. Foreground Grass framing the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: -10, // Slight negative offset to ensure it covers the bottom edge completely
            child: IgnorePointer(
              child: Image.asset(
                _grassPath,
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          // 4. Back Button (Top Left)
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F), // Yellow matching the prototype UI buttons
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 0,
                            offset: Offset(2, 4),
                          )
                        ]
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
