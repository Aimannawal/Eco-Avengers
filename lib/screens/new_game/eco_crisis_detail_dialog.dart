import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/game_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

class EcoCrisisDetailDialog extends StatefulWidget {
  final GlobalIssue issue;
  final VoidCallback? onSuccess;
  final VoidCallback? onFailure;

  const EcoCrisisDetailDialog({
    Key? key,
    required this.issue,
    this.onSuccess,
    this.onFailure,
  }) : super(key: key);

  @override
  State<EcoCrisisDetailDialog> createState() =>   _EcoCrisisDetailDialogState();
}

class _EcoCrisisDetailDialogState extends State<EcoCrisisDetailDialog>
    with TickerProviderStateMixin {
  late AnimationController _diceController;
  String? _diceResult;
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _diceController.dispose();
    super.dispose();
  }

  void _rollDice() {
    if (_isRolling) return;

    setState(() {
      _isRolling = true;
      _diceResult = null;
    });

    _diceController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      
      final randomIndex = math.Random().nextInt(GAME_DICE.length);
      final result = GAME_DICE[randomIndex].value;

      setState(() {
        _diceResult = result;
        _isRolling = false;
      });

      // Call callback based on result
      if (result == 'fail') {
        widget.onFailure?.call();
      } else {
        widget.onSuccess?.call();
      }
    });
  }

  bool get _isSuccess => _diceResult != null && _diceResult != 'fail';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 32,
              offset: const Offset(0, 16),
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 24,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Issue header with color
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.issue.color.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.issue.title,
                            style: AppTheme.titleMedium.copyWith(
                              fontSize: 24,
                              color: widget.issue.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.issue.hashtag,
                            style: AppTheme.subtitleSmall.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: widget.issue.color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Difficulty Level ${widget.issue.difficultyLevel}',
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 13,
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFE74C3C),
                              Color(0xFFF2C94C),
                              Color(0xFF2ECC71),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Description
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textSecondary.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.issue.description,
                    style: AppTheme.subtitleRegular.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Dice roller section
                if (_diceResult == null)
                  Column(
                    children: [
                      Text(
                        'Roll the Dice',
                        style: AppTheme.titleMedium.copyWith(
                          fontSize: 18,
                          color: AppColors.primaryDarkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dice display grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: GAME_DICE.length,
                        itemBuilder: (context, index) {
                          final dice = GAME_DICE[index];
                          return _buildDicePreview(dice);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Roll button
                      GestureDetector(
                        onTap: _isRolling ? null : _rollDice,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDarkGreen,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDarkGreen.withOpacity(
                                  _isRolling ? 0.4 : 0.25,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            _isRolling ? 'Rolling...' : 'Roll Dice',
                            textAlign: TextAlign.center,
                            style: AppTheme.subtitleRegular.copyWith(
                              fontSize: 16,
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      // Result display
                      _buildResultDisplay(),
                      const SizedBox(height: 16),
                      // Outcome description
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? const Color(0xFF2ECC71).withOpacity(0.1)
                              : const Color(0xFFE74C3C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSuccess
                                ? const Color(0xFF2ECC71)
                                : const Color(0xFFE74C3C),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSuccess ? 'SUCCESS!' : 'FAILED!',
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 16,
                                color: _isSuccess
                                    ? const Color(0xFF2ECC71)
                                    : const Color(0xFFE74C3C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSuccess
                                  ? widget.issue.successEffect
                                  : widget.issue.failureEffect,
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDarkGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Continue',
                              textAlign: TextAlign.center,
                              style: AppTheme.subtitleRegular.copyWith(
                                fontSize: 15,
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDicePreview(DiceFace dice) {
    return Container(
      decoration: BoxDecoration(
        color: dice.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dice.color.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: dice.color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: dice.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                dice.value,
                style: AppTheme.titleMedium.copyWith(
                  fontSize: 24,
                  color: AppColors.pureWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              dice.description,
              textAlign: TextAlign.center,
              style: AppTheme.captionText.copyWith(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDisplay() {
    final result = GAME_DICE.firstWhere((d) => d.value == _diceResult);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            result.color.withOpacity(0.15),
            result.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.color.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          RotationTransition(
            turns: _diceController,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: result.color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: result.color.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _diceResult ?? '',
                  style: AppTheme.titleMedium.copyWith(
                    fontSize: 40,
                    color: AppColors.pureWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You rolled: ${_diceResult}',
            style: AppTheme.subtitleRegular.copyWith(
              fontSize: 18,
              color: result.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.description,
            textAlign: TextAlign.center,
            style: AppTheme.subtitleSmall.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
