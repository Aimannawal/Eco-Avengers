import 'package:flutter/material.dart';

// Action Card Model
class ActionCard {
  final String id;
  final String title;
  final String description;
  final String? iconAssetPath;
  final Color color;
  final List<TokenEffect> effects; // e.g., Energy -1, Peace +2
  final bool isSpecial;

  ActionCard({
    required this.id,
    required this.title,
    required this.description,
    this.iconAssetPath,
    required this.color,
    required this.effects,
    this.isSpecial = false,
  });
}

// Token Effect
class TokenEffect {
  final String tokenType; // 'energy', 'peace', 'crisis'
  final int modifier; // positive or negative

  TokenEffect({required this.tokenType, required this.modifier});
}

// Global Issue (Eco Crisis Card)
class GlobalIssue {
  final String id;
  final String title;
  final String hashtag;
  final String description;
  final int difficultyLevel;
  final String successEffect;
  final String failureEffect;
  final String? iconAssetPath;
  final Color color;

  GlobalIssue({
    required this.id,
    required this.title,
    required this.hashtag,
    required this.description,
    required this.difficultyLevel,
    required this.successEffect,
    required this.failureEffect,
    this.iconAssetPath,
    required this.color,
  });
}

// Game State
class GameRound {
  final int roundNumber;
  final String selectedCharacterId;
  final String selectedDifficulty;
  String selectedRegion = 'Africa';
  late final int initialEcoCrisisLevel;
  late int currentEcoCrisisLevel;
  
  // Current state
  int energy = 0;
  int peace = 0;
  int crisisTokens = 0;
  
  List<ActionCard> handCards = [];
  List<ActionCard> usedCards = [];
  List<GlobalIssue> activeIssues = [];
  
  int successCount = 0;
  int failCount = 0;

  // Badge unlock state: maps badgeType → highest level unlocked (0=none, 1/2/3=level)
  // Badge types: 'energy', 'ecology', 'climate'
  Map<String, int> unlockedBadgeLevels = {
    'energy': 0,
    'ecology': 0,
    'climate': 0,
  };

  /// Unlock the next badge level for the given type (max 3).
  /// Returns true if a new badge was actually unlocked.
  bool unlockBadge(String badgeType) {
    final current = unlockedBadgeLevels[badgeType] ?? 0;
    if (current < 3) {
      unlockedBadgeLevels[badgeType] = current + 1;
      return true;
    }
    return false; // already at max level
  }

  /// Get current unlock level for a badge type (0 = none unlocked).
  int getBadgeLevel(String badgeType) {
    return unlockedBadgeLevels[badgeType] ?? 0;
  }

  GameRound({
    required this.roundNumber,
    required this.selectedCharacterId,
    required this.selectedDifficulty,
  }) {
    // Initialize based on difficulty
    _initializeByDifficulty();
    _initializeEcoCrisis();
  }

  void _initializeEcoCrisis() {
    initialEcoCrisisLevel = _getLevelByDifficulty();
    currentEcoCrisisLevel = initialEcoCrisisLevel;
  }

  int _getLevelByDifficulty() {
    switch (selectedDifficulty.toLowerCase()) {
      case 'easy':
        return 3;
      case 'normal':
        return 4;
      case 'hard':
        return 5;
      default:
        return 4;
    }
  }

  void setRegion(String region) {
    selectedRegion = region;
  }

  void updateEcoCrisisLevel(int newLevel) {
    currentEcoCrisisLevel = newLevel;
  }

  void _initializeByDifficulty() {
    switch (selectedDifficulty.toLowerCase()) {
      case 'easy':
        energy = 8;
        crisisTokens = 2;
        break;
      case 'normal':
        energy = 6;
        crisisTokens = 3;
        break;
      case 'hard':
        energy = 4;
        crisisTokens = 4;
        break;
      default:
        energy = 6;
        crisisTokens = 3;
    }
    peace = 5;
  }

  void addActionCard(ActionCard card) {
    handCards.add(card);
  }

  void useCard(ActionCard card) {
    handCards.removeWhere((c) => c.id == card.id);
    usedCards.add(card);
    
    // Apply token effects
    for (final effect in card.effects) {
      applyEffect(effect);
    }
  }

  void applyEffect(TokenEffect effect) {
    switch (effect.tokenType.toLowerCase()) {
      case 'energy':
        energy = (energy + effect.modifier).clamp(0, 999);
        break;
      case 'peace':
        peace = (peace + effect.modifier).clamp(0, 999);
        break;
      case 'crisis':
        crisisTokens = (crisisTokens + effect.modifier).clamp(0, 999);
        break;
    }
  }

  void solveGlobalIssue(GlobalIssue issue, bool isSuccess) {
    if (isSuccess) {
      successCount++;
    } else {
      failCount++;
    }
    activeIssues.removeWhere((i) => i.id == issue.id);
  }
}

// Master Token Reference (untuk menjelaskan apa itu token)
class TokenReference {
  final String name;
  final String description;
  final Color color;
  final String? iconPath;

  TokenReference({
    required this.name,
    required this.description,
    required this.color,
    this.iconPath,
  });
}

// Dice Face
class DiceFace {
  final String value; // '1', '2', 'fail', 'fail'
  final Color color;
  final String description;

  DiceFace({
    required this.value,
    required this.color,
    required this.description,
  });
}

// Sample dice data (1, 2, fail, fail)
final List<DiceFace> GAME_DICE = [
  DiceFace(
    value: '1',
    color: const Color(0xFFFF6B6B),
    description: 'Remove 1 difficulty token',
  ),
  DiceFace(
    value: '2',
    color: const Color(0xFF4ECDC4),
    description: 'Remove 2 difficulty tokens',
  ),
  DiceFace(
    value: 'fail',
    color: const Color(0xFFFFE66D),
    description: 'Move crisis 1 step forward',
  ),
  DiceFace(
    value: 'fail',
    color: const Color(0xFFFFE66D),
    description: 'Move crisis 1 step forward',
  ),
];
