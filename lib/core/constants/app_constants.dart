// ============================================================
// APP CONSTANTS
// Konstanta umum untuk logika game multiplayer
// ============================================================

class AppConstants {
  AppConstants._();

  // ── Room Settings ─────────────────────────────────────────
  static const int minPlayers = 3;
  static const int maxPlayers = 5;
  static const int roomCodeLength = 6;

  // ── Room Status ───────────────────────────────────────────
  static const String statusWaiting = 'waiting';
  static const String statusCharacterSelect = 'character_select';
  static const String statusPlaying = 'playing';
  static const String statusFinished = 'finished';

  // ── Difficulty ────────────────────────────────────────────
  static const String difficultyEasy = 'easy';
  static const String difficultyNormal = 'normal';
  static const String difficultyHard = 'hard';

  // ── Initial Token Values by Difficulty ───────────────────
  static const Map<String, Map<String, int>> difficultyTokens = {
    'easy': {'energy': 8, 'peace': 5, 'crisis_tokens': 2, 'eco_crisis_level': 3},
    'normal': {'energy': 6, 'peace': 5, 'crisis_tokens': 3, 'eco_crisis_level': 4},
    'hard': {'energy': 4, 'peace': 5, 'crisis_tokens': 4, 'eco_crisis_level': 5},
  };

  // ── Character IDs (sesuai dengan CharacterOption.title) ───
  static const String charEnvironmentalActivist = 'environmental_activist';
  static const String charPolicymaker = 'policymaker';
  static const String charClimateEngineer = 'climate_engineer';
  static const String charEcologist = 'ecologist';
  static const String charEnergyScientist = 'energy_scientist';

  // ── SharedPreferences Keys ────────────────────────────────
  static const String prefPlayerId = 'player_id';
  static const String prefPlayerName = 'player_name';
}
