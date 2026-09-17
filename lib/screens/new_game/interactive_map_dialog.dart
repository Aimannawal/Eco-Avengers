import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/room_model.dart';

class MapLocation {
  final String name;
  final Offset position; // Center of the geographical region (0-1, 0-1 normalized)
  final Offset pinPosition; // Where the bottom tip of the pin should point
  final double radius; // Clickable radius in normalized coordinates
  final String iconAsset;

  const MapLocation({
    required this.name,
    required this.position,
    required this.pinPosition,
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
  /// If true, the map is only for viewing. Tapping regions will trigger onRegionSelected but won't move the character visually.
  final bool viewOnly;

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
    this.viewOnly = false,
  }) : super(key: key);

  @override
  State<InteractiveMapDialog> createState() => _InteractiveMapDialogState();
}

class _InteractiveMapDialogState extends State<InteractiveMapDialog>
    with TickerProviderStateMixin {
  
  // Exact coordinates matching the 541x448 map (16).png
  static const List<MapLocation> mapLocations = [
    MapLocation(
      name: 'North America',
      position: Offset(0.197, 0.395),
      pinPosition: Offset(0.197, 0.330),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Climate Engineering.png',
    ),
    MapLocation(
      name: 'Central & South America',
      position: Offset(0.306, 0.678),
      pinPosition: Offset(0.306, 0.614),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Climate Engineering.png',
    ),
    MapLocation(
      name: 'Europe',
      position: Offset(0.584, 0.292),
      pinPosition: Offset(0.584, 0.228),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Energy Science.png',
    ),
    MapLocation(
      name: 'Africa',
      position: Offset(0.557, 0.511),
      pinPosition: Offset(0.557, 0.446),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Environmental Ecology.png',
    ),
    MapLocation(
      name: 'Asia',
      position: Offset(0.877, 0.400),
      pinPosition: Offset(0.877, 0.335),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Environmental Ecology.png',
    ),
    MapLocation(
      name: 'Oceania',
      position: Offset(0.881, 0.725),
      pinPosition: Offset(0.881, 0.661),
      radius: 0.12,
      iconAsset: 'assets/token/Professional Icon Token-Environmental Ecology.png',
    ),
  ];

  static const String _mapBackgroundPath = 'assets/Element Eco Avenger/map/image-removebg-preview (16).png';
  static const String _waterBackground = 'assets/Element Eco Avenger/Multiplayer page/background (2).png';
  static const String _grassForeground = 'assets/Element Eco Avenger/Menu page/START_20260830_140036_0000.pdf_20260904_083830_0000.png';
  static const String _redPin = 'assets/Element Eco Avenger/map/image-removebg-preview (17).png';

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
      (loc) => loc.name.toLowerCase() == widget.initialRegion.toLowerCase(),
      orElse: () => mapLocations.firstWhere(
        (loc) => loc.name == 'Africa',
        orElse: () => mapLocations[0],
      ),
    );

    _currentLocation = initialLocation.name;
    _currentCharacterPos = initialLocation.pinPosition;

    _moveController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
    if (widget.viewOnly) {
      _animatePinTo(location);
      widget.onRegionSelected?.call(location.name);
      return;
    }

    // In forceSelect mode, if already picked, don't allow re-selection
    if (widget.forceSelect && _hasPicked) return;

    if (_currentLocation == location.name) {
      // Validate region before confirming
      if (widget.onValidateRegion != null) {
        final isValid = await widget.onValidateRegion!(location.name);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${location.name} was already picked by another player! Choose a different region.',
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
          end: location.pinPosition,
        ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
        );

    _moveController.forward(from: 0.0).then((_) async {
      setState(() {
        _currentLocation = location.name;
        _currentCharacterPos = location.pinPosition;
      });

      // Validate region before confirming
      if (widget.onValidateRegion != null) {
        final isValid = await widget.onValidateRegion!(location.name);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${location.name} was already picked by another player! Choose a different region.',
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
        setState(() => _hasPicked = true);
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void _animatePinTo(MapLocation location) {
    if (_currentLocation == location.name && !_moveController.isAnimating) return;

    _characterPosition = Tween<Offset>(
      begin: _currentCharacterPos,
      end: location.pinPosition,
    ).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOut),
    );

    _moveController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentLocation = location.name;
          _currentCharacterPos = location.pinPosition;
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
        } catch (_) {}
      }
    });
    return occupants;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 500;
    final double grassHeight = isCompact ? size.height * 0.25 : size.height * 0.18;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero, // Make it fullscreen
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Water Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_waterBackground),
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
                _grassForeground,
                height: grassHeight,
                fit: BoxFit.cover,
              ),
            ),

            // 3. Main Content Layer
            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 20,
                    bottom: grassHeight * 0.5,
                    left: 20,
                    right: 20,
                  ),
                  child: AspectRatio(
                    aspectRatio: 541 / 448, // Exact aspect ratio of 16.png
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The map scroll image
                        Positioned.fill(
                          child: Image.asset(
                            _mapBackgroundPath,
                            fit: BoxFit.fill,
                          ),
                        ),
                        
                        // Hitboxes and Pins/Pawns
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, mapConstraints) {
                              final mapW = mapConstraints.maxWidth;
                              final mapH = mapConstraints.maxHeight;
                              
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 1. Clickable Hitboxes for each region
                                  ...mapLocations.map((location) {
                                    final occupants = _getOccupantsOfRegion(location.name);
                                    
                                    // Map position is the center
                                    final left = location.position.dx * mapW;
                                    final top = location.position.dy * mapH;
                                    // Clickable area box (based on radius)
                                    final boxWidth = mapW * location.radius * 2;
                                    final boxHeight = mapH * location.radius * 2;
                                    
                                    return Positioned(
                                      left: left - (boxWidth / 2),
                                      top: top - (boxHeight / 2),
                                      width: boxWidth,
                                      height: boxHeight,
                                      child: GestureDetector(
                                        onTap: () => _moveCharacterToLocation(location),
                                        behavior: HitTestBehavior.opaque,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            // Other players' occupants
                                            if (occupants.isNotEmpty)
                                              Positioned(
                                                bottom: isCompact ? -10 : -20,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: occupants.map((p) {
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          border: Border.all(color: Colors.white, width: 2),
                                                          boxShadow: [
                                                            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                                                          ],
                                                        ),
                                                        child: CircleAvatar(
                                                          radius: isCompact ? 12 : 18,
                                                          backgroundColor: const Color(0xFF38A3A5),
                                                          backgroundImage: p.characterAsset != null
                                                              ? AssetImage(p.characterAsset!)
                                                              : null,
                                                          child: p.characterAsset == null
                                                              ? const Icon(Icons.person, color: Colors.white, size: 16)
                                                              : null,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),

                                  // 2. My Selection Animation (Red Pin)
                                  if (!widget.forceSelect || _hasPicked || _moveController.isAnimating)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _moveController,
                                          builder: (context, _) {
                                            final displayPos = _moveController.isAnimating
                                                ? _characterPosition.value
                                                : _currentCharacterPos;
                                            
                                            final pinW = isCompact ? 32.0 : 44.0;
                                            final pinH = isCompact ? 44.0 : 60.0;

                                            // Center pin horizontally over location
                                            final pinLeft = (displayPos.dx * mapW) - (pinW / 2);
                                            // Pin bottom tip touches the top border of the continent label
                                            final pinTop = (displayPos.dy * mapH) - pinH + (isCompact ? 6 : 8);

                                            return Transform.translate(
                                              offset: Offset(pinLeft, pinTop),
                                              child: Align(
                                                alignment: Alignment.topLeft,
                                                child: SizedBox(
                                                  width: pinW,
                                                  height: pinH,
                                                  child: TweenAnimationBuilder<double>(
                                                    key: ValueKey(_currentLocation),
                                                    tween: Tween(begin: 0.0, end: 1.0),
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.elasticOut,
                                                    builder: (context, value, child) {
                                                      return Transform.scale(
                                                        scale: value,
                                                        alignment: Alignment.bottomCenter,
                                                        child: child,
                                                      );
                                                    },
                                                    child: Image.asset(
                                                      _redPin,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        
                        // Close Button (Red X)
                        if (!widget.forceSelect || _hasPicked)
                        if (widget.myPlayerId == null || (_effectiveRegions != null && _effectiveRegions![widget.myPlayerId] != null))
                        Positioned(
                          top: isCompact ? -5 : 5,
                          right: isCompact ? -5 : 15,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, offset: Offset(2, 2), blurRadius: 4),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: isCompact ? 14 : 18,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, color: Colors.white, size: isCompact ? 18 : 24, weight: 800),
                              ),
                            ),
                          ),
                        ),

                        // Waiting for others overlay
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
                                        'Region selected! ✓',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFA5C18A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Waiting for other players to pick a region...',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${_effectiveRegions?.length ?? 0}/${widget.totalPlayers} players have picked',
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
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
