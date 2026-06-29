import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'character_selection_page.dart';

enum _NewGameStep { mode, difficulty }

class NewGameModal extends StatefulWidget {
  const NewGameModal({Key? key}) : super(key: key);

  @override
  State<NewGameModal> createState() => _NewGameModalState();
}

class _NewGameModalState extends State<NewGameModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  _NewGameStep _step = _NewGameStep.mode;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSingleplayerModes() {
    setState(() {
      _step = _NewGameStep.difficulty;
    });
  }

  void _showMultiplayerSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Multiplayer coming soon')));
  }

  void _selectDifficulty(String difficulty) {
    Navigator.of(context, rootNavigator: true)
        .push<String>(
          MaterialPageRoute(
            builder: (_) => CharacterSelectionPage(
              difficulty: difficulty,
              characters: const [
                CharacterOption(
                  title: 'Environmental Activist',
                  description:
                      'Move two spaces forward at once during your turn.',
                  assetPath:
                      'assets/character/Character Sheet-Environmental Activist.png',
                  accentColor: Color(0xFF38A3A5),
                ),
                CharacterOption(
                  title: 'Policymaker',
                  description:
                      'Adds 1 to the first derived dice value for other players in range.',
                  assetPath:
                      'assets/character/Character Sheet-Policymaker.png',
                  accentColor: Color(0xFFB07D54),
                ),
                CharacterOption(
                  title: 'Climate Engineer',
                  description: 'Decreases Climate Resilience difficulty by 1.',
                  assetPath:
                      'assets/character/Character Sheet-Climate Engineer.png',
                  accentColor: Color(0xFFF06292),
                ),
                CharacterOption(
                  title: 'Ecologist',
                  description:
                      'Decreases Environmental Degradation difficulty by 1.',
                  assetPath:
                      'assets/character/Character Sheet-Ecologist.png',
                  accentColor: Color(0xFFED9B3B),
                ),
                CharacterOption(
                  title: 'Energy Scientist',
                  description: 'Decreases Energy Crisis difficulty by 1.',
                  assetPath:
                      'assets/character/Character Sheet-Energy Scientist.png',
                  accentColor: Color(0xFF4F7DBA),
                ),
              ],
            ),
          ),
        )
        .then((selectedCharacter) {
          if (selectedCharacter != null && mounted) {
            Navigator.of(
              context,
            ).pop('singleplayer:$difficulty:$selectedCharacter');
          }
        });
  }

  Widget _buildModePage() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTile(
            title: 'Singleplayer',
            subtitle: 'Calm, strategy-focused solo mission',
            color: AppColors.secondaryGreen,
            icon: Icons.person,
            onTap: _showSingleplayerModes,
          ),
          const SizedBox(height: 6),
          _ModeTile(
            title: 'Multiplayer',
            subtitle: 'Competitive, social strategy',
            color: AppColors.essentialBlueAccent,
            icon: Icons.group,
            onTap: _showMultiplayerSoon,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyPage() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTile(
            title: 'Easy',
            subtitle: 'Relaxed pace for learning the game',
            color: AppColors.secondaryGreen,
            icon: Icons.sentiment_satisfied_alt_rounded,
            onTap: () => _selectDifficulty('easy'),
          ),
          const SizedBox(height: 6),
          _ModeTile(
            title: 'Normal',
            subtitle: 'Balanced challenge and strategy',
            color: AppColors.secondaryGreen,
            icon: Icons.straighten_rounded,
            onTap: () => _selectDifficulty('normal'),
          ),
          const SizedBox(height: 6),
          _ModeTile(
            title: 'Hard',
            subtitle: 'For experienced players only',
            color: AppColors.secondaryGreen,
            icon: Icons.local_fire_department_rounded,
            onTap: () => _selectDifficulty('hard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Make modal slightly larger on both small and wide screens
    final modalWidth = screenWidth < 600 ? screenWidth * 0.9 : 340.0;

    return ScaleTransition(
      scale: _anim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: modalWidth,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDarkGreen.withOpacity(0.16),
                    blurRadius: 32,
                    offset: const Offset(0, 20),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _step == _NewGameStep.mode
                        ? _buildModePage()
                        : _buildDifficultyPage(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_pressed ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTheme.subtitleRegular.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: AppTheme.captionText.copyWith(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
