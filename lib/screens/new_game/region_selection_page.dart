import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game_play_screen.dart';

class RegionSelectionPage extends StatefulWidget {
  final String difficulty;
  final String selectedCharacterId;
  final String selectedCharacterName;
  final Color characterAccentColor;
  final String? characterAssetPath;

  const RegionSelectionPage({
    required this.difficulty,
    required this.selectedCharacterId,
    required this.selectedCharacterName,
    required this.characterAccentColor,
    this.characterAssetPath,
    Key? key,
  }) : super(key: key);

  @override
  State<RegionSelectionPage> createState() => _RegionSelectionPageState();
}

class _RegionSelectionPageState extends State<RegionSelectionPage>
    with SingleTickerProviderStateMixin {
  
  // Percentage-based bounding boxes for the 6 regions on the scroll map.
  // Format: [left, top, width, height] as fractions of the image's dimensions (0.0 to 1.0).
  static const Map<String, List<double>> _regionHitboxes = {
    'North America': [0.10, 0.30, 0.26, 0.20],
    'Europe': [0.44, 0.20, 0.24, 0.20],
    'Asia': [0.70, 0.26, 0.23, 0.20],
    'Central & South America': [0.20, 0.58, 0.25, 0.20],
    'Africa': [0.42, 0.44, 0.24, 0.20],
    'Oceania': [0.68, 0.62, 0.24, 0.20],
  };

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  
  String? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onRegionTap(String region) {
    if (_selectedRegion != null) return; // Prevent multiple taps
    
    setState(() {
      _selectedRegion = region;
    });

    // Wait a brief moment to show the pin animation, then navigate
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GamePlayScreen(
            selectedCharacterId: widget.selectedCharacterId,
            selectedCharacterName: widget.selectedCharacterName,
            selectedDifficulty: widget.difficulty,
            characterAccentColor: widget.characterAccentColor,
            characterAssetPath: widget.characterAssetPath,
            selectedRegion: region,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 500;
    
    final double grassHeight = isCompact ? size.height * 0.25 : size.height * 0.18;

    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Water Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/Element Eco Avenger/Multiplayer page/background (2).png'),
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),
          
          // 2. Grass Foreground at the bottom
          Positioned(
            bottom: -5,
            left: -10,
            right: -10,
            child: Image.asset(
              'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_083830_0000.png',
              height: grassHeight,
              fit: BoxFit.cover,
            ),
          ),

          // 3. Main Content Layer
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 20,
                    bottom: grassHeight * 0.5, // keep above grass
                    left: 20,
                    right: 20,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.25, // Rough aspect ratio of the 16.png map
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The map scroll image
                        Positioned.fill(
                          child: Image.asset(
                            'assets/Element Eco Avenger/map/image-removebg-preview (16).png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        
                        // Hitboxes and Pins
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final h = constraints.maxHeight;
                              
                              return Stack(
                                children: _regionHitboxes.entries.map((entry) {
                                  final regionName = entry.key;
                                  final coords = entry.value;
                                  final left = coords[0] * w;
                                  final top = coords[1] * h;
                                  final width = coords[2] * w;
                                  final height = coords[3] * h;
                                  
                                  final isSelected = _selectedRegion == regionName;
                                  
                                  return Positioned(
                                    left: left,
                                    top: top,
                                    width: width,
                                    height: height,
                                    child: GestureDetector(
                                      onTap: () => _onRegionTap(regionName),
                                      behavior: HitTestBehavior.opaque,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          // Debug semi-transparent color if you want to see the hitboxes:
                                          // Container(color: Colors.red.withOpacity(0.3)),
                                          
                                          // The Red Pin
                                          if (isSelected)
                                            Positioned(
                                              // Adjust pin slightly above the center
                                              top: -height * 0.1,
                                              child: TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0.0, end: 1.0),
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.elasticOut,
                                                builder: (context, value, child) {
                                                  return Transform.translate(
                                                    offset: Offset(0, -20 * (1 - value)),
                                                    child: Transform.scale(
                                                      scale: value,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                                child: Image.asset(
                                                  'assets/Element Eco Avenger/map/image-removebg-preview (17).png',
                                                  width: isCompact ? 30 : 45,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                        
                        // 4. Close Button (Red X)
                        Positioned(
                          top: isCompact ? -5 : 5,
                          right: isCompact ? -5 : 15,
                          child: GestureDetector(
                            onTap: () {
                              if (_selectedRegion == null) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 4),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, color: Colors.white, size: 24, weight: 800),
                              ),
                            ),
                          ),
                        ),
                        
                      ],
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
