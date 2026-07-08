import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/menu_button.dart';
import '../widgets/user_avatar.dart';
import 'auth/login_register_screen.dart';
import 'leaderboard/leaderboard_screen.dart';
import 'new_game/mode_selection_page.dart';
import 'profile/profile_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  static const Color _buttonGreen = Color(0xFFA5C18A);
  static const Color _buttonBorder = Color(0xFF111111);
  static const String _howToPlayUrl =
      'https://drive.google.com/file/d/1Pcu5HlE9P5EEzcGFdPEb8IbsrO4hPYuV/view';

  bool _isLoggedIn = false;
  String? _username;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (loggedIn) {
      final username = await AuthService.instance.getUsername();
      final avatarUrl = await AuthService.instance.getAvatarUrl();
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _username = username;
          _avatarUrl = avatarUrl;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _username = null;
          _avatarUrl = null;
        });
      }
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onNewGamePressed() {
    if (!_isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModeSelectionPage()),
    );
  }

  void _onLeaderboardPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  void _onProfilePressed() {
    if (_isLoggedIn) {
      // Show Profile Dialog
      _showProfileDialog();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      );
    }
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (_) => ProfileDialog(
        onProfileUpdated: _loadProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/background/homespage.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.06)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.05, -0.12),
                    radius: 1.08,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.08),
                    ],
                    stops: const [0.62, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactWidth = constraints.maxWidth < 760;
                  final buttonWidth = math
                      .min(
                        isCompactWidth
                            ? constraints.maxWidth * 0.64
                            : constraints.maxWidth * 0.38,
                        360.0,
                      )
                      .toDouble();

                  return SizedBox.expand(
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompactWidth ? 24 : 32,
                              vertical: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _HomeMenuButton(
                                  label: 'START',
                                  width: buttonWidth,
                                  height: isCompactWidth ? 44 : 58,
                                  fontSize: isCompactWidth ? 17 : 24,
                                  onPressed: _onNewGamePressed,
                                ),
                                SizedBox(height: isCompactWidth ? 12 : 14),
                                _HomeMenuButton(
                                  label: 'HOW TO PLAY',
                                  width: buttonWidth,
                                  height: isCompactWidth ? 44 : 58,
                                  fontSize: isCompactWidth ? 14 : 21,
                                  onPressed: _onHowToPlayPressed,
                                ),
                                SizedBox(height: isCompactWidth ? 12 : 14),
                                _HomeMenuButton(
                                  label: 'LEADERBOARD',
                                  width: buttonWidth,
                                  height: isCompactWidth ? 44 : 58,
                                  fontSize: isCompactWidth ? 14 : 21,
                                  onPressed: _onLeaderboardPressed,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Profile Button Top Right
                        Positioned(
                          top: isCompactWidth ? 16 : 24,
                          right: isCompactWidth ? 16 : 24,
                          child: GestureDetector(
                            onTap: _onProfilePressed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _HomeScreenState._buttonGreen,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _HomeScreenState._buttonBorder, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    avatarUrl: _avatarUrl,
                                    name: _isLoggedIn ? (_username ?? '?') : '?',
                                    radius: 14.0,
                                    borderWidth: 1.5,
                                    borderColor: Colors.transparent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isLoggedIn ? (_username ?? 'Player') : 'Login',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Future<void> _onHowToPlayPressed() async {
    final uri = Uri.parse(_howToPlayUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka panduan how to play.')),
      );
    }
  }
}

class _HomeMenuButton extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final double fontSize;
  final VoidCallback onPressed;

  const _HomeMenuButton({
    required this.label,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(51),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _HomeScreenState._buttonGreen,
            borderRadius: BorderRadius.circular(51),
            border: Border.all(color: _HomeScreenState._buttonBorder, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
