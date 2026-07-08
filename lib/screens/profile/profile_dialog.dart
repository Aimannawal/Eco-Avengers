import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:feather_icons/feather_icons.dart';

import '../../models/leaderboard_model.dart';
import 'image_positioning_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/user_avatar.dart';

class ProfileDialog extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const ProfileDialog({Key? key, required this.onProfileUpdated})
    : super(key: key);

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  PlayerProfile? _profile;
  List<GameResult>? _recentGames;
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isSaving = false;

  // Edit Profile controllers
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _bioController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();
    final profile = await LeaderboardService.instance.getPlayerProfile(
      playerId,
    );
    final games = await LeaderboardService.instance.getRecentResults(
      playerId,
      limit: 10,
    );

    if (mounted) {
      setState(() {
        _profile = profile;
        _recentGames = games;
        if (profile != null) {
          _nameController.text = profile.displayName;
          _countryController.text = profile.country ?? '';
          _bioController.text = profile.bio ?? '';
        } else {
          AuthService.instance.getUsername().then((username) {
            if (mounted && username != null) {
              _nameController.text = username;
            }
          });
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak bisa membuka galeri: $e\nPastikan izin galeri sudah diberikan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (pickedFile == null) {
      // User cancelled or permission denied - show hint
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada foto dipilih. Pastikan izin akses galeri sudah diizinkan di pengaturan HP.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Show positioning dialog for user to adjust crop
    if (!mounted) return;
    final File? croppedFile = await showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImagePositioningDialog(
        imageFile: File(pickedFile!.path),
      ),
    );

    // User cancelled positioning
    if (croppedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengeditan foto dibatalkan'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    final url = await AuthService.instance.uploadAvatar(croppedFile);
    if (mounted) {
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengunggah foto. Cek koneksi internet & pastikan Storage Policy Supabase sudah dibuat.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diubah! ✓'), backgroundColor: Colors.green),
        );
      }
    }
    await _loadData();
    setState(() => _isUploading = false);
    widget.onProfileUpdated();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final res = await AuthService.instance.updateProfile(
      displayName: _nameController.text.trim(),
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
    );
    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
        widget.onProfileUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Gagal update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    widget.onProfileUpdated();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF111111), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header & Tabs
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4A6741),
                borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PLAYER PROFILE',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFA5C18A),
                    indicatorWeight: 4,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'OVERVIEW'),
                      Tab(text: 'EDIT'),
                      Tab(text: 'HISTORY'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A6741),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildEditTab(),
                        _buildHistoryTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  avatarUrl: _profile?.avatarUrl,
                  name: _profile?.displayName ?? '?',
                  radius: 50.0,
                  fontSize: 40.0,
                  borderWidth: 2.0,
                ),
                if (_isUploading)
                  const CircularProgressIndicator(color: Color(0xFF4A6741)),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA5C18A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF111111),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Name & Bio
          Text(
            _profile?.displayName ?? 'Player',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (_profile?.country != null && _profile!.country!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    FeatherIcons.flag,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _profile!.country!,
                    style: GoogleFonts.montserrat(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (_profile?.bio != null && _profile!.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '"${_profile!.bio!}"',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Stats Row
          Row(
            children: [
              _buildStatCard(
                'WINS',
                '${_profile?.totalWins ?? 0}',
                const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'LOSSES',
                '${_profile?.totalLosses ?? 0}',
                const Color(0xFFEB5757),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                'WIN RATE',
                '${_profile?.winRate ?? 0}%',
                const Color(0xFF2D9CDB),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'BEST SCORE',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB8860B),
                  ),
                ),
                Text(
                  '${_profile?.bestScore ?? 0}',
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(FeatherIcons.logOut, color: Color(0xFFEB5757)),
              label: Text(
                'LOGOUT',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEB5757),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFEB5757), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    IconData icon;
    if (label == 'WINS') {
      icon = Icons.emoji_events_rounded;
    } else if (label == 'LOSSES') {
      icon = Icons.close_rounded;
    } else if (label == 'WIN RATE') {
      icon = Icons.trending_up_rounded;
    } else {
      icon = Icons.star_rounded;
    }
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EDIT PROFILE',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nameController,
              label: 'Display Name *',
              icon: FeatherIcons.user,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _countryController,
              label: 'Country',
              icon: FeatherIcons.flag,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bioController,
              label: 'Bio',
              icon: FeatherIcons.edit2,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA5C18A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF111111), width: 2),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'SAVE CHANGES',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF4A6741)),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 13,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A6741), width: 2),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_recentGames == null || _recentGames!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FeatherIcons.inbox, size: 48, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              'Belum ada riwayat main',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recentGames!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final game = _recentGames![index];
        final isWin = game.isWin;
        final color = isWin ? const Color(0xFF4CAF50) : const Color(0xFFEB5757);
        
        // Format date with day name
        final now = DateTime.now();
        final diff = now.difference(game.playedAt);
        String timeAgo;
        if (diff.inDays == 0) {
          if (diff.inHours == 0) {
            timeAgo = '${diff.inMinutes}m ago';
          } else {
            timeAgo = '${diff.inHours}h ago';
          }
        } else if (diff.inDays < 7) {
          timeAgo = '${diff.inDays}d ago';
        } else {
          final weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][game.playedAt.weekday % 7];
          timeAgo = '$weekday, ${game.playedAt.day}/${game.playedAt.month}';
        }


        return GestureDetector(
          onTap: () => _showGameDetailDialog(context, game),
          child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Character avatar
              if (game.character != null && game.character!.isNotEmpty)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                    image: DecorationImage(
                      image: AssetImage('assets/vector/${game.character} Profile.png'),
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -2),
                    ),
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2.5),
                  ),
                  child: Icon(
                    isWin ? FeatherIcons.award : FeatherIcons.xCircle,
                    color: color,
                    size: 26,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isWin ? 'WIN' : 'LOSS',
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${game.character ?? 'Unknown'} · ${game.region ?? '?'}',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          game.mode == 'multiplayer'
                              ? FeatherIcons.users
                              : FeatherIcons.user,
                          size: 13,
                          color: game.mode == 'multiplayer'
                              ? const Color(0xFF4A6741)
                              : const Color(0xFF8D6E63),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${game.difficulty ?? "Normal"} · Score: ${game.score}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _showGameDetailDialog(BuildContext context, GameResult game) {
    final isWin = game.isWin;
    final color = isWin ? const Color(0xFF4CAF50) : const Color(0xFFEB5757);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF111111), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  border: Border(bottom: BorderSide(color: color.withOpacity(0.3), width: 2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF111111), width: 2),
                      ),
                      child: Text(
                        isWin ? 'VICTORY' : 'DEFEAT',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              // Content (scrollable on small screens)
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (game.character != null && game.character!.isNotEmpty)
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 3),
                              image: DecorationImage(
                                image: AssetImage('assets/vector/${game.character} Profile.png'),
                                fit: BoxFit.cover,
                                alignment: const Alignment(0, -2),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          game.character ?? 'Unknown Character',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _detailRow(Icons.public_rounded, 'Region', game.region ?? 'Unknown'),
                        _detailRow(Icons.speed_rounded, 'Difficulty', game.difficulty ?? 'Normal'),
                        _detailRow(
                          game.mode == 'multiplayer' ? Icons.people_rounded : Icons.person_rounded,
                          'Mode',
                          game.mode == 'multiplayer' ? 'Multiplayer' : 'Singleplayer',
                        ),
                        _detailRow(Icons.emoji_events_rounded, 'Score', '${game.score} pts', valueColor: const Color(0xFF4A6741)),
                        _detailRow(Icons.calendar_today_rounded, 'Played', _formatDate(game.playedAt)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
