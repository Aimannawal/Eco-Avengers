import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../models/room_model.dart';

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
  final Map<String, String>? existingPlayerRegions;
  final List<RoomPlayer>? players;
  final String? myPlayerId;
  /// When true, the dialog cannot be dismissed until a region is selected.
  /// Used for initial multiplayer map selection.
  final bool forceSelect;
  /// Total players count for showing progress (used with forceSelect).
  final int totalPlayers;
  /// Called before confirming region selection. Returns true if valid (no conflict).
  /// Used to prevent race conditions where two players pick the same region.
  final Future<bool> Function(String region)? onValidateRegion;
  /// Notifier for real-time region updates from parent (streams from Supabase).
  /// When updated, the dialog refreshes occupied regions immediately.
  final ValueNotifier<Map<String, String>>? regionsNotifier;

  const InteractiveMapDialog({
    Key? key,
    required this.characterName,
    required this.characterAccentColor,
    this.onRegionSelected,
    this.initialRegion = 'North America',
    this.existingPlayerRegions,
    this.players,
    this.myPlayerId,
    this.forceSelect = false,
    this.totalPlayers = 0,
    this.onValidateRegion,
    this.regionsNotifier,
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

  // Track whether a region has been picked (for forceSelect mode)
  bool _hasPicked = false;

  // Real-time regions map (updated via notifier)
  Map<String, String>? _liveRegions;

  /// Effective regions: live (from notifier) takes priority over initial snapshot
  Map<String, String>? get _effectiveRegions => _liveRegions ?? widget.existingPlayerRegions;

  @override
  void initState() {
    super.initState();
    _liveRegions = widget.existingPlayerRegions;
    widget.regionsNotifier?.addListener(_onRegionsUpdated);

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
    widget.regionsNotifier?.removeListener(_onRegionsUpdated);
    super.dispose();
  }

  void _onRegionsUpdated() {
    if (!mounted) return;
    setState(() {
      _liveRegions = widget.regionsNotifier?.value;
    });
  }

  void _moveCharacterToLocation(MapLocation location) async {
    // In forceSelect mode, if already picked, don't allow re-selection
    if (widget.forceSelect && _hasPicked) return;

    if (_currentLocation == location.name) {
      // Validate region before confirming (prevents race condition)
      if (widget.onValidateRegion != null) {
        final isValid = await widget.onValidateRegion!(location.name);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${location.name} sudah dipilih pemain lain! Pilih region lain.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      widget.onRegionSelected?.call(location.name);
      if (widget.forceSelect) {
        // Don't pop — let parent handle dismissal after all players pick
        setState(() => _hasPicked = true);
      } else {
        Navigator.of(context).pop();
      }
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

    _moveController.forward(from: 0.0).then((_) async {
      setState(() {
        _currentLocation = location.name;
        _currentCharacterPos = location.position;
      });

      // Validate region before confirming (prevents race condition)
      if (widget.onValidateRegion != null) {
        final isValid = await widget.onValidateRegion!(location.name);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${location.name} sudah dipilih pemain lain! Pilih region lain.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // Call the region selection callback if provided
      widget.onRegionSelected?.call(location.name);

      if (widget.forceSelect) {
        // Don't pop — let parent handle dismissal after all players pick
        setState(() => _hasPicked = true);
      } else {
        // Close the dialog after a short delay to show the final position
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  List<RoomPlayer> _getOccupantsOfRegion(String regionName) {
    final regions = _effectiveRegions;
    if (regions == null || widget.players == null) return [];
    final List<RoomPlayer> occupants = [];
    regions.forEach((pid, reg) {
      if (reg == regionName && pid != widget.myPlayerId) {
        try {
          final p = widget.players!.firstWhere(
            (player) => player.playerId == pid,
          );
          occupants.add(p);
        } catch (_) {
          // Player not found in list, skip
        }
      }
    });
    return occupants;
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

                    final buttonW = isWide 
                        ? (mapW * 0.28).clamp(100.0, 210.0) 
                        : (mapW * 0.26).clamp(80.0, 150.0);
                    final buttonH = isWide
                        ? (mapH * 0.25).clamp(55.0, 100.0)
                        : (mapH * 0.22).clamp(42.0, 75.0);

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
                          final occupants = _getOccupantsOfRegion(location.name);
                          final isOccupied = occupants.isNotEmpty;

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
                              isOccupied: isOccupied,
                              occupants: occupants,
                              onTap: isOccupied
                                  ? () {
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${location.name} is occupied by ${occupants.map((o) => o.playerName).join(", ")}!',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  : () => _moveCharacterToLocation(location),
                            ),
                          );
                        }).toList(),

                        // 3. Animated Character Pawn standing on top of the selected region button
                        // In forceSelect mode, hide pawn until player picks a region
                        if (!widget.forceSelect || _hasPicked)
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
                        // In forceSelect mode, only show close button AFTER picking a region
                        if (!widget.forceSelect || _hasPicked)
                        if (widget.myPlayerId == null || (_effectiveRegions != null && _effectiveRegions![widget.myPlayerId] != null))
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

                        // 6. Waiting-for-others overlay (forceSelect mode after picking)
                        if (widget.forceSelect && _hasPicked)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.black.withOpacity(0.55),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: Color(0xFFA5C18A),
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Region dipilih! ✓',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFA5C18A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Menunggu pemain lain memilih region...',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${_effectiveRegions?.length ?? 0}/${widget.totalPlayers} pemain sudah pilih',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
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
  final bool isOccupied;
  final List<RoomPlayer> occupants;
  final VoidCallback onTap;

  const _RegionButton({
    required this.location,
    required this.isSelected,
    required this.isWide,
    required this.buttonW,
    required this.buttonH,
    required this.isOccupied,
    required this.occupants,
    required this.onTap,
  });

  @override
  State<_RegionButton> createState() => _RegionButtonState();
}

class _RegionButtonState extends State<_RegionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = (widget.buttonH * 0.45).clamp(20.0, 38.0);
    // Occupied avatar: much larger, like leaderboard profile photos
    final avatarSize = (widget.buttonH * 0.55).clamp(28.0, 52.0);

    Color cardColor = const Color(0xFFFAF8F5);
    BorderSide borderSide = const BorderSide(
      color: Color(0xFFE5E0D8),
      width: 1.5,
    );

    if (widget.isOccupied) {
      cardColor = const Color(0xFFFBEBEB); // light red for occupied
      borderSide = const BorderSide(
        color: Color(0xFFE89A9A),
        width: 1.5,
      );
    } else if (widget.isSelected) {
      borderSide = const BorderSide(
        color: Color(0xFF38A3A5),
        width: 3.0,
      );
    }

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
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.fromBorderSide(borderSide),
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
                  fontSize: (widget.buttonH * 0.15).clamp(6.5, 11.0),
                  fontWeight: FontWeight.w900,
                  color: widget.isOccupied ? Colors.red.shade900 : Colors.black87,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Occupied: show big character photo + name
              widget.isOccupied
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Large character photo (zoomed in like leaderboard)
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.shade400, width: 2),
                            image: widget.occupants.first.characterAsset != null
                                ? DecorationImage(
                                    image: AssetImage(widget.occupants.first.characterAsset!),
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.medium,
                                  )
                                : null,
                            color: Colors.white,
                          ),
                          child: widget.occupants.first.characterAsset == null
                              ? Icon(Icons.person, size: avatarSize * 0.5, color: Colors.red.shade400)
                              : null,
                        ),
                        const SizedBox(height: 2),
                        // Character name tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          constraints: BoxConstraints(maxWidth: widget.buttonW - 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.occupants.first.characterName ?? widget.occupants.first.playerName,
                            style: GoogleFonts.montserrat(
                              fontSize: (widget.buttonH * 0.11).clamp(5.5, 9.0),
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.occupants.length > 1)
                          Text(
                            '+${widget.occupants.length - 1} more',
                            style: GoogleFonts.montserrat(
                              fontSize: 7,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    )
                  : Row(
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
