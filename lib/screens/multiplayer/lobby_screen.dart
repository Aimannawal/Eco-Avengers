// ============================================================
// LOBBY SCREEN
// Layar untuk create room atau join room via kode
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../services/room_service.dart';
import '../../services/supabase_service.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String difficulty;

  const LobbyScreen({super.key, required this.difficulty});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  static const Color _feltColor = Color(0xFF6A9073);
  static const Color _borderColor = Color(0xFF111111);
  static const Color _buttonColor = Color(0xFFA5C18A);

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _prefillName();
  }

  Future<void> _prefillName() async {
    final name = await SupabaseService.instance.getPlayerName();
    if (name != null && mounted) {
      _nameController.text = name;
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _difficultyLabel {
    switch (widget.difficulty) {
      case AppConstants.difficultyEasy:
        return 'Easy';
      case AppConstants.difficultyHard:
        return 'Hard';
      default:
        return 'Normal';
    }
  }

  Future<void> _createRoom() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Masukkan nama pemain kamu dulu!');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await RoomService.instance.createRoom(
        difficulty: widget.difficulty,
        playerName: name,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            room: room,
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membuat room: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Masukkan nama pemain kamu dulu!');
      return;
    }
    if (code.length != AppConstants.roomCodeLength) {
      setState(() => _errorMessage = 'Kode room harus ${AppConstants.roomCodeLength} karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final room = await RoomService.instance.joinRoom(
        roomCode: code,
        playerName: name,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            room: room,
            playerName: name,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background/kayu.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.12)),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  final isCompact = constraints.maxHeight < 500;
                  final boardWidth = isWide
                      ? math.min(constraints.maxWidth * 0.70, 600.0)
                      : constraints.maxWidth * 0.90;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 24),
                      child: SizedBox(
                        width: boardWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // ── Main Board ──
                            Container(
                              decoration: BoxDecoration(
                                color: _feltColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: _borderColor, width: 3.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.fromLTRB(
                                24,
                                isCompact ? 20 : 36,
                                24,
                                isCompact ? 16 : 28,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title
                                  Text(
                                    'MULTIPLAYER',
                                    style: GoogleFonts.montserrat(
                                      fontSize: isCompact ? 18 : (isWide ? 28 : 22),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Difficulty badge
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: isCompact ? 2 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.20),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Text(
                                      'Mode: $_difficultyLabel  •  ${AppConstants.minPlayers}–${AppConstants.maxPlayers} Pemain',
                                      style: GoogleFonts.montserrat(
                                        fontSize: isCompact ? 10 : 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 14 : 28),

                                  // Name input
                                  _LobbyTextField(
                                    controller: _nameController,
                                    hint: 'Nama kamu',
                                    icon: Icons.person_outline_rounded,
                                    compact: isCompact,
                                    readOnly: true,
                                  ),
                                  SizedBox(height: isCompact ? 10 : 20),

                                  // Divider
                                  Row(children: [
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        color: Colors.white.withOpacity(0.25),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'PILIH AKSI',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white60,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1.5,
                                        color: Colors.white.withOpacity(0.25),
                                      ),
                                    ),
                                  ]),
                                  SizedBox(height: isCompact ? 10 : 20),

                                  // Create Room Button
                                  _LobbyButton(
                                    label: 'BUAT ROOM',
                                    icon: Icons.add_circle_outline_rounded,
                                    color: _buttonColor,
                                    isLoading: _isLoading,
                                    onTap: _createRoom,
                                    compact: isCompact,
                                  ),
                                  SizedBox(height: isCompact ? 8 : 16),

                                  // Divider "ATAU"
                                  Row(children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'ATAU',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                  ]),
                                  SizedBox(height: isCompact ? 8 : 16),

                                  // Join Room input + button
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _LobbyTextField(
                                          controller: _codeController,
                                          hint: 'Kode Room (6 huruf)',
                                          icon: Icons.vpn_key_outlined,
                                          maxLength: AppConstants.roomCodeLength,
                                          textCapitalization: TextCapitalization.characters,
                                          compact: isCompact,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      _JoinButton(
                                        isLoading: _isLoading,
                                        onTap: _joinRoom,
                                        borderColor: _borderColor,
                                        buttonColor: _buttonColor,
                                        compact: isCompact,
                                      ),
                                    ],
                                  ),

                                  // Error message
                                  if (_errorMessage != null) ...[
                                    SizedBox(height: isCompact ? 8 : 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.20),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.red.shade200,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Back button (top-left chip)
                            Positioned(
                              left: -14,
                              top: -14,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    width: isWide ? 56 : 48,
                                    height: isWide ? 56 : 48,
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
                                      size: isWide ? 28 : 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ── Helper Widgets ────────────────────────────────────────────

class _LobbyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final bool compact;
  final bool readOnly;

  const _LobbyTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLength,
    this.textCapitalization = TextCapitalization.words,
    this.compact = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: GoogleFonts.montserrat(
        fontSize: compact ? 13 : 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(
          fontSize: compact ? 12 : 14,
          color: Colors.white54,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: Colors.white60, size: compact ? 18 : 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFA5C18A), width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 8 : 14,
        ),
      ),
    );
  }
}

class _LobbyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  final bool compact;

  const _LobbyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(51),
        child: Container(
          width: double.infinity,
          height: compact ? 40 : 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(51),
            border: Border.all(color: const Color(0xFF111111), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading
              ? SizedBox(
                  width: compact ? 18 : 22,
                  height: compact ? 18 : 22,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black54,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: compact ? 16 : 20, color: Colors.black87),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: compact ? 13 : 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  final Color borderColor;
  final Color buttonColor;
  final bool compact;

  const _JoinButton({
    required this.isLoading,
    required this.onTap,
    required this.borderColor,
    required this.buttonColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: compact ? 56 : 68,
          height: compact ? 40 : 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading
              ? SizedBox(
                  width: compact ? 14 : 18,
                  height: compact ? 14 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black54,
                  ),
                )
              : Text(
                  'JOIN',
                  style: GoogleFonts.montserrat(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}


