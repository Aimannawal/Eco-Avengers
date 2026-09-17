import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/sound_service.dart';
import 'auth/login_register_screen.dart';
import 'leaderboard/leaderboard_screen.dart';
import 'new_game/mode_selection_page.dart';
import 'profile/profile_dialog.dart';

// ── ASSET PATHS ──────────────────────────────────────────────────────────────
const _kBase = 'assets/Element Eco Avenger/Start page/';
const _kBg = '${_kBase}bg.png';
const _kLogo = '${_kBase}Logo eco avenger.png';
const _kRumputForeground = '${_kBase}rumput.png';
const _kGrassMound = '${_kBase}START_20260830_140036_0000.pdf_20260904_082302_0000.png';
const _kBushDetail = '${_kBase}START_20260830_140036_0000.pdf_20260904_082113_0000.png';
const _kSparkles = '${_kBase}START_20260830_140036_0000.pdf_20260904_082045_0000.png';

// Characters & Tree
const _kCharHijab = '${_kBase}START_20260830_140036_0000.pdf_20260904_082135_0000.png';
const _kCharBlueSuit = '${_kBase}START_20260830_140036_0000.pdf_20260904_082153_0000.png';
const _kCharWhiteShirt = '${_kBase}START_20260830_140036_0000.pdf_20260904_082248_0000.png';
const _kTree = '${_kBase}START_20260830_140036_0000.pdf_20260904_082221_0000.png';

// Cropped clean buttons (matching aspect ratio and crisp bounds)
const _kBtnPlay = '${_kBase}btn_play.png';
const _kBtnHow = '${_kBase}btn_how.png';
const _kBtnLeaderboard = '${_kBase}btn_leaderboard.png';
const _kMusicIcon = '${_kBase}btn_music.png';
const _kProfileIcon = '${_kBase}profile.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _sparkleCtrl;
  late AnimationController _runCtrl;

  late Animation<double> _fadeAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _sparkleAnim;
  late Animation<double> _runAnim;

  bool _isLoggedIn = false;
  String? _username;
  String? _avatarUrl;
  bool _musicOn = true;

  static const String _howToPlayUrl =
      'https://drive.google.com/drive/folders/18EefL9mSZ4pz9ys0KcBkWazvS4MR3niS';

  @override
  void initState() {
    super.initState();
    _musicOn = SoundService.instance.isMusicEnabled;
    _initAnimations();
    _loadProfile();
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Floating logo animation
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Twinkling sparkles
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _sparkleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleCtrl, curve: Curves.easeInOut),
    );

    // Slight run bounce for characters
    _runCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _runAnim = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _runCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadProfile() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
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

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _floatCtrl.dispose();
    _sparkleCtrl.dispose();
    _runCtrl.dispose();
    super.dispose();
  }

  void _onPlay() {
    if (!_isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      ).then((_) => _loadProfile());
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModeSelectionPage()),
    );
  }

  void _onLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
    );
  }

  void _onProfile() {
    if (_isLoggedIn) {
      showDialog(
        context: context,
        builder: (_) => ProfileDialog(onProfileUpdated: _loadProfile),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
      ).then((_) => _loadProfile());
    }
  }

  Future<void> _onHowToPlay() async {
    final uri = Uri.parse(_howToPlayUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open how-to-play guide.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    // Responsive scaling
    final isCompact = w < 700;

    // On landscape phone (short height), scale everything down significantly
    final scaleFactor = isLandscape ? math.min(h / 500, 1.0) : 1.0;

    // Logo dimensions: BIG and bold across top
    final logoW = math.min(
      isCompact ? w * 0.88 : w * 0.78,
      isLandscape ? h * 0.6 : 640.0,
    ) * scaleFactor;

    // Button dimensions: exactly proportional and matching
    final btnW = math.min(
      isCompact ? w * 0.36 : w * 0.28,
      isLandscape ? h * 0.3 : 230.0,
    ) * scaleFactor;
    final btnH = btnW / 2.68;
    final btnSpacing = (isCompact ? 8.0 : 12.0) * scaleFactor;

    // Landscape proportions
    final grassMoundH = isCompact ? h * 0.32 : h * 0.38;
    final grassForegroundH = isCompact ? h * 0.34 : h * 0.40;
    final treeH = isCompact ? h * 0.32 : h * 0.38;
    final charH = isCompact ? h * 0.20 : h * 0.23;

    return Scaffold(
      backgroundColor: const Color(0xFF75B9E7),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. BACKGROUND SKY ──────────────────────────────────────────────
          Image.asset(
            _kBg,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // ── 2. GRASS MOUND (Background ground behind characters) ────────────
          Positioned(
            bottom: h * 0.08,
            left: 0,
            right: 0,
            child: Image.asset(
              _kGrassMound,
              fit: BoxFit.fill,
              height: grassMoundH,
            ),
          ),

          // ── 3. TREE (Right side) ───────────────────────────────────────────
          Positioned(
            bottom: h * 0.16,
            right: isCompact ? w * 0.08 : w * 0.14,
            child: Image.asset(
              _kTree,
              height: treeH,
              fit: BoxFit.contain,
            ),
          ),

          // ── 4. BUSH CLUMP (Left side behind hijab girl) ─────────────────────
          Positioned(
            bottom: h * 0.17,
            left: isCompact ? w * 0.14 : w * 0.18,
            child: Image.asset(
              _kBushDetail,
              height: charH * 0.60,
              fit: BoxFit.contain,
            ),
          ),

          // ── 5. CHARACTERS RUNNING ──────────────────────────────────────────
          AnimatedBuilder(
            animation: _runAnim,
            builder: (_, __) => Stack(
              children: [
                // Char 1: Hijab girl (Left)
                Positioned(
                  bottom: h * 0.17 + _runAnim.value,
                  left: isCompact ? w * 0.18 : w * 0.22,
                  child: Image.asset(
                    _kCharHijab,
                    height: charH,
                    fit: BoxFit.contain,
                  ),
                ),

                // Char 2: Blue suit boy (Center-Left)
                Positioned(
                  bottom: h * 0.17 - _runAnim.value,
                  left: isCompact ? w * 0.28 : w * 0.32,
                  child: Image.asset(
                    _kCharBlueSuit,
                    height: charH * 1.04,
                    fit: BoxFit.contain,
                  ),
                ),

                // Char 3: White shirt boy (Center-Right near tree)
                Positioned(
                  bottom: h * 0.17 + _runAnim.value * 0.8,
                  right: isCompact ? w * 0.22 : w * 0.26,
                  child: Image.asset(
                    _kCharWhiteShirt,
                    height: charH * 1.04,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),

          // ── 6. FOREGROUND BUSHES (rumput.png with dip in center) ────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              _kRumputForeground,
              fit: BoxFit.fill,
              height: grassForegroundH,
            ),
          ),

          // ── 7. MAIN UI LAYER ───────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Stack(
                children: [
                  // ── CENTER: Logo + Buttons (scrollable on very small screens) ─
                  Positioned.fill(
                    child: SingleChildScrollView(
                      // Only activates when content is too tall (e.g. landscape phone)
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: isLandscape ? 50 : 60),
                            // Animated floating Logo + Sparkles
                            AnimatedBuilder(
                              animation: _floatAnim,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, _floatAnim.value),
                                child: child,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    _kLogo,
                                    width: logoW,
                                    fit: BoxFit.contain,
                                  ),

                                  // Twinkling sparkle top-left of 'E'
                                  Positioned(
                                    top: -6,
                                    left: logoW * 0.21,
                                    child: FadeTransition(
                                      opacity: _sparkleAnim,
                                      child: Image.asset(
                                        _kSparkles,
                                        width: isCompact ? 20 : 26,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  // Twinkling sparkle left of 'A'
                                  Positioned(
                                    bottom: 10,
                                    left: logoW * 0.05,
                                    child: FadeTransition(
                                      opacity: _sparkleAnim,
                                      child: Image.asset(
                                        _kSparkles,
                                        width: isCompact ? 18 : 22,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isCompact ? 14 : 20),

                            // Play Button
                            _PixelActionButton(
                              assetPath: _kBtnPlay,
                              width: btnW,
                              height: btnH,
                              onPressed: _onPlay,
                            ),

                            SizedBox(height: btnSpacing),

                            // How to Play Button
                            _PixelActionButton(
                              assetPath: _kBtnHow,
                              width: btnW,
                              height: btnH,
                              onPressed: _onHowToPlay,
                            ),

                            SizedBox(height: btnSpacing),

                            // Leaderboard Button
                            _PixelActionButton(
                              assetPath: _kBtnLeaderboard,
                              width: btnW,
                              height: btnH,
                              onPressed: _onLeaderboard,
                            ),
                            // Bottom padding so content doesn't hide behind grass
                            SizedBox(height: grassForegroundH * 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── TOP LEFT: Music button (Top layer) ──────────────────────
                  Positioned(
                    top: isCompact ? 12 : 18,
                    left: isCompact ? 14 : 22,
                    child: _MusicButton(
                      musicOn: _musicOn,
                      onTap: () async {
                        await SoundService.instance.toggleMusic();
                        if (mounted) {
                          setState(() => _musicOn = SoundService.instance.isMusicEnabled);
                        }
                      },
                    ),
                  ),

                  // ── TOP RIGHT: Profile button (Top layer) ───────────────────
                  Positioned(
                    top: isCompact ? 12 : 18,
                    right: isCompact ? 14 : 22,
                    child: _ProfileButton(
                      isLoggedIn: _isLoggedIn,
                      username: _username,
                      onTap: _onProfile,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── PIXEL ACTION BUTTON WITH BOUNCE FEEDBACK ──────────────────────────────────
class _PixelActionButton extends StatefulWidget {
  final String assetPath;
  final double width;
  final double height;
  final VoidCallback onPressed;

  const _PixelActionButton({
    Key? key,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<_PixelActionButton> createState() => _PixelActionButtonState();
}

class _PixelActionButtonState extends State<_PixelActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        transform: _pressed
            ? Matrix4.translationValues(0, 3.5, 0)
            : Matrix4.identity(),
        child: Image.asset(
          widget.assetPath,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

// ── MUSIC BUTTON (Clean pixel note with mute toggle) ─────────────────────────
class _MusicButton extends StatefulWidget {
  final bool musicOn;
  final VoidCallback onTap;

  const _MusicButton({Key? key, required this.musicOn, required this.onTap})
      : super(key: key);

  @override
  State<_MusicButton> createState() => _MusicButtonState();
}

class _MusicButtonState extends State<_MusicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: widget.musicOn ? 1.0 : 0.45,
              child: Image.asset(
                _kMusicIcon,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
            ),
            if (!widget.musicOn)
              CustomPaint(
                size: const Size(36, 36),
                painter: _MuteStrikePainter(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── PROFILE BUTTON (Pixel art card matching concept) ──────────────────────────
class _ProfileButton extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final VoidCallback onTap;

  const _ProfileButton({
    Key? key,
    required this.isLoggedIn,
    this.username,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<_ProfileButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: _pressed
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        child: Tooltip(
          message: widget.isLoggedIn
              ? (widget.username ?? 'Profile')
              : 'Login / Register',
          child: Image.asset(
            _kProfileIcon,
            width: 36,
            height: 42,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ── RED MUTE LINE PAINTER ────────────────────────────────────────────────────
class _MuteStrikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
