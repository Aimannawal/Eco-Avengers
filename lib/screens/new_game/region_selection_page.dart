import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
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
  static const List<String> _regions = [
    'Africa',
    'Asia',
    'Europe',
    'North America',
    'Central & South America',
  ];

  static const Map<String, Color> _regionColors = {
    'Africa': Color(0xFFED9B3B),
    'Asia': Color(0xFF4F7DBA),
    'Europe': Color(0xFF38A3A5),
    'North America': Color(0xFFF06292),
    'Central & South America': Color(0xFFB07D54),
  };

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

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

  void _selectRegion(String region) {
    Navigator.of(context).push(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background/select-char.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.12)),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxHeight < 500;
                  final titleSize = isMobile ? 18.0 : 24.0;
                  final topGap = isMobile ? 8.0 : 32.0;
                  final cardVertPad = isMobile ? 8.0 : 16.0;
                  final cardFontSize = isMobile ? 14.0 : 18.0;
                  final hPad = isMobile ? 12.0 : 16.0;
                  final vPad = isMobile ? 8.0 : 24.0;
                  final bottomGap = isMobile ? 6.0 : 12.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SELECT REGION',
                          style: GoogleFonts.montserrat(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: topGap),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _regions.length,
                            itemBuilder: (context, index) {
                              final region = _regions[index];
                              final color = _regionColors[region] ?? AppColors.secondaryGreen;

                              return Padding(
                                padding: EdgeInsets.only(bottom: bottomGap),
                                child: _RegionCard(
                                  region: region,
                                  color: color,
                                  cardVertPad: cardVertPad,
                                  cardFontSize: cardFontSize,
                                  onTap: () => _selectRegion(region),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionCard extends StatefulWidget {
  final String region;
  final Color color;
  final VoidCallback onTap;
  final double cardVertPad;
  final double cardFontSize;

  const _RegionCard({
    required this.region,
    required this.color,
    required this.onTap,
    this.cardVertPad = 16.0,
    this.cardFontSize = 18.0,
  });

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.cardVertPad),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_pressed ? 0.28 : 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.color.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            if (_pressed)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: widget.cardVertPad * 2.4,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.region,
                style: GoogleFonts.montserrat(
                  fontSize: widget.cardFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
