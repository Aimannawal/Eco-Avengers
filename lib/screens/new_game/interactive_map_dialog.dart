import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

class MapLocation {
  final String name;
  final Offset
  position; // Center of the geographical region (0-1, 0-1 normalized)
  final double radius; // Clickable radius in normalized coordinates
  final String iconAsset;

  const MapLocation({
    required this.name,
    required this.position,
    required this.radius,
    required this.iconAsset,
  });
}

class InteractiveMapDialog extends StatefulWidget {
  final String characterName;
  final Color characterAccentColor;
  final Function(String)? onRegionSelected;
  final String initialRegion;

  const InteractiveMapDialog({
    Key? key,
    required this.characterName,
    required this.characterAccentColor,
    this.onRegionSelected,
    this.initialRegion = 'North America',
  }) : super(key: key);

  @override
  State<InteractiveMapDialog> createState() => _InteractiveMapDialogState();
}

class _InteractiveMapDialogState extends State<InteractiveMapDialog>
    with TickerProviderStateMixin {
  // Map locations on map-polos.png
  static const List<MapLocation> mapLocations = [
    MapLocation(
      name: 'North America',
      position: Offset(0.24, 0.36),
      radius: 0.08,
      iconAsset: 'assets/token/Professional Icon Token-Climate Engineering.png',
    ),
    MapLocation(
      name: 'Central & South America',
      position: Offset(0.28, 0.70),
      radius: 0.07,
      iconAsset:
          'assets/token/Professional Icon Token-Climate Engineering.png',
    ),
    MapLocation(
      name: 'Europe',
      position: Offset(0.52, 0.28),
      radius: 0.06,
      iconAsset: 'assets/token/Professional Icon Token-Energy Science.png',
    ),
    MapLocation(
      name: 'Africa',
      position: Offset(0.59, 0.58),
      radius: 0.07,
      iconAsset: 'assets/token/Professional Icon Token-Environmental Ecology.png',
    ),
    MapLocation(
      name: 'Asia',
      position: Offset(0.78, 0.32),
      radius: 0.09,
      iconAsset: 'assets/token/Professional Icon Token-Environmental Ecology.png',
    ),
  ];

  static const String _mapBackgroundPath = 'assets/background/map-polos.png';
  static const String _characterPath = 'assets/background/char.png';

  late AnimationController _moveController;
  late Animation<Offset> _characterPosition;

  late String _currentLocation;
  late Offset _currentCharacterPos;

  @override
  void initState() {
    super.initState();

    // Find the location matching the initial region
    final initialLocation = mapLocations.firstWhere(
      (loc) => loc.name == widget.initialRegion,
      orElse: () => mapLocations[0],
    );

    _currentLocation = initialLocation.name;
    _currentCharacterPos = initialLocation.position;

    _moveController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  void _moveCharacterToLocation(MapLocation location) {
    if (_currentLocation == location.name) {
      widget.onRegionSelected?.call(location.name);
      Navigator.of(context).pop();
      return;
    }

    // Create animation from current position to target position
    _characterPosition =
        Tween<Offset>(
          begin: _currentCharacterPos,
          end: location.position,
        ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
        );

    _moveController.forward(from: 0.0).then((_) {
      setState(() {
        _currentLocation = location.name;
        _currentCharacterPos = location.position;
      });

      // Call the region selection callback if provided
      widget.onRegionSelected?.call(location.name);

      // Close the dialog after a short delay to show the final position
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LayoutBuilder(
        builder: (context, dialogConstraints) {
          final isWide = dialogConstraints.maxWidth >= 760;

          // Fit the map container while maintaining aspect ratio (4:3)
          final maxMapWidth = math.min(
            dialogConstraints.maxWidth * 0.96,
            960.0,
          );
          final maxMapHeight = math.min(
            dialogConstraints.maxHeight * 0.90,
            720.0,
          );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxMapWidth,
                maxHeight: maxMapHeight,
              ),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: LayoutBuilder(
                  builder: (context, mapConstraints) {
                    final mapW = mapConstraints.maxWidth;
                    final mapH = mapConstraints.maxHeight;

                    // Pawn and button dimensions relative to map dimensions
                    final pawnW = mapW * 0.07;
                    final pawnH = mapH * 0.12;

                    final buttonW = isWide ? 200.0 : 148.0;
                    final buttonH = isWide ? 88.0 : 72.0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Plain Map Background
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: const Color(
                                0xFFF1ECE4,
                              ), // parchment canvas
                              child: Image.asset(
                                _mapBackgroundPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppColors.softGray.withOpacity(0.12),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 40,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // 2. Scattered Continent Selection Cards
                        ...mapLocations.map((location) {
                          final isSelected = _currentLocation == location.name;

                          // Position the card directly at continent coordinates
                          return Positioned(
                            left: location.position.dx * mapW - (buttonW * 0.6),
                            top: location.position.dy * mapH - (buttonH / 2),
                            child: _RegionButton(
                              location: location,
                              isSelected: isSelected,
                              isWide: isWide,
                              buttonW: buttonW,
                              buttonH: buttonH,
                              onTap: () => _moveCharacterToLocation(location),
                            ),
                          );
                        }).toList(),

                        // 3. Animated Character Pawn standing on top of the selected region button
                        AnimatedBuilder(
                          animation: _moveController,
                          builder: (context, child) {
                            final displayPos = _moveController.isAnimating
                                ? _characterPosition.value
                                : _currentCharacterPos;

                            // Calculate the card's position dynamically based on current animate coordinates
                            final cardLeft = displayPos.dx * mapW - (buttonW * 0.6);
                            final cardTop = displayPos.dy * mapH - (buttonH / 2);

                            // Position pawn precisely in the center of the right half of the card
                            final pawnLeft = cardLeft + (buttonW * 0.75) - (pawnW / 2);
                            final pawnTop = cardTop + (buttonH / 2) - (pawnH / 2);

                            return Positioned(
                              left: pawnLeft,
                              top: pawnTop,
                              child: child!,
                            );
                          },
                          child: SizedBox(
                            width: pawnW,
                            height: pawnH,
                            child: Image.asset(
                              _characterPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: widget.characterAccentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // 4. Top Header Banner Overlay
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6A9073,
                                ), // green felt board theme
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFF111111),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                'SELECT TARGET LOCATION',
                                style: GoogleFonts.montserrat(
                                  fontSize: isWide ? 15 : 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 5. Close Button
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RegionButton extends StatefulWidget {
  final MapLocation location;
  final bool isSelected;
  final bool isWide;
  final double buttonW;
  final double buttonH;
  final VoidCallback onTap;

  const _RegionButton({
    required this.location,
    required this.isSelected,
    required this.isWide,
    required this.buttonW,
    required this.buttonH,
    required this.onTap,
  });

  @override
  State<_RegionButton> createState() => _RegionButtonState();
}

class _RegionButtonState extends State<_RegionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.isWide ? 38.0 : 28.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.buttonW,
          height: widget.buttonH,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F5), // Premium off-white card tone
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF38A3A5) // Highlight color
                  : const Color(0xFFE5E0D8), // Subtle off-white border
              width: widget.isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFF38A3A5).withOpacity(0.25)
                    : Colors.black.withOpacity(0.08),
                blurRadius: widget.isSelected ? 10 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Region Name centered at top
              Text(
                widget.location.name.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: widget.isWide ? 10.0 : 7.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Token Row (token left-aligned, space on right if selected for pawn)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: widget.isWide ? 12.0 : 6.0),
                    child: Image.asset(
                      widget.location.iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
