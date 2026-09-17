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
import '../../widgets/retro_window.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String difficulty;

  const LobbyScreen({super.key, required this.difficulty});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
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
      setState(() => _errorMessage = 'Please enter your player name first!');
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
      setState(() => _errorMessage = 'Failed to create room: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your player name first!');
      return;
    }
    if (code.length != AppConstants.roomCodeLength) {
      setState(() => _errorMessage = 'Room code must be ${AppConstants.roomCodeLength} characters.');
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
            'assets/Element Eco Avenger/Menu page/bg.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = math.min(constraints.maxWidth * 0.92, 520.0);
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: maxWidth,
                        child: _buildRetroLobbyContent(),
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

  Widget _buildRetroLobbyContent() {
    return RetroWindow(
      title: 'Multiplayer',
      titleIcon: Icons.info,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            '${_difficultyLabel.toUpperCase()} MODE ${AppConstants.minPlayers}-${AppConstants.maxPlayers} PLAYERS',
            style: GoogleFonts.vt323(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Name Input Box
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFC0C0C0),
              border: Border(
                top: BorderSide(color: Colors.black, width: 2),
                left: BorderSide(color: Colors.black, width: 2),
                bottom: BorderSide(color: Colors.white, width: 2),
                right: BorderSide(color: Colors.white, width: 2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.person, color: Colors.yellow, size: 36),
                ),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: GoogleFonts.vt323(fontSize: 24, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFA0A0A0), // darker grey
                      hintText: 'Player Name',
                      hintStyle: GoogleFonts.vt323(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            'CHOOSE ACTION',
            style: GoogleFonts.vt323(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          
          // Create Room Button
          GestureDetector(
            onTap: _isLoading ? null : _createRoom,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Create Room',
                    style: GoogleFonts.vt323(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          Text(
            'OR',
            style: GoogleFonts.vt323(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Join Room Row
          Row(
            children: [
              // Room Code Input
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFC0C0C0),
                    border: Border(
                      top: BorderSide(color: Colors.black, width: 2),
                      left: BorderSide(color: Colors.black, width: 2),
                      bottom: BorderSide(color: Colors.white, width: 2),
                      right: BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.vpn_key, color: Colors.orangeAccent, size: 24),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          style: GoogleFonts.vt323(fontSize: 20, color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: AppConstants.roomCodeLength,
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFA0A0A0),
                            hintText: 'Room Code ( 6 letters )',
                            hintStyle: GoogleFonts.vt323(color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Join Button
              GestureDetector(
                onTap: _isLoading ? null : _joinRoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: Text(
                    'Join',
                    style: GoogleFonts.vt323(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.vt323(color: Colors.red[900], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(color: Colors.black)),
            ),
            
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


