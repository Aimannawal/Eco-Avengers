import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/supabase_constants.dart';
import '../models/eco_idea_model.dart';
import 'supabase_service.dart';

class EcoIdeasService {
  EcoIdeasService._();
  static final EcoIdeasService instance = EcoIdeasService._();

  static const String _prefKeyEcoIdeas = 'cached_eco_ideas_list';

  /// Save a new Eco Idea both locally and to Supabase
  Future<EcoIdea> saveIdea({
    required String cardTitle,
    String? cardAssetPath,
    required String region,
    required int crisisLevel,
    required String solutionText,
  }) async {
    final playerId = await SupabaseService.instance.getOrCreatePlayerId();
    final playerName = await SupabaseService.instance.getPlayerName() ?? 'Eco Hero';

    final idea = EcoIdea(
      id: const Uuid().v4(),
      playerId: playerId,
      playerName: playerName,
      cardTitle: cardTitle,
      cardAssetPath: cardAssetPath,
      region: region,
      crisisLevel: crisisLevel,
      solutionText: solutionText.trim(),
      createdAt: DateTime.now(),
    );

    // 1. Save to local SharedPreferences first (offline-first resilience)
    await _saveLocalIdea(idea);

    // 2. Try inserting into Supabase
    try {
      await SupabaseService.instance.client
          .from(SupabaseConstants.tableEcoIdeas)
          .insert(idea.toJson());
    } catch (e) {
      debugPrint('EcoIdeasService: Saved locally; Supabase upload error: $e');
    }

    return idea;
  }

  /// Retrieve all Eco Ideas for a specific player (from Supabase or local cache)
  Future<List<EcoIdea>> getIdeas(String playerId) async {
    // 1. Try fetching from Supabase
    try {
      final res = await SupabaseService.instance.client
          .from(SupabaseConstants.tableEcoIdeas)
          .select()
          .eq('player_id', playerId)
          .order('created_at', ascending: false);

      if (res.isNotEmpty) {
        final onlineList = res
            .map((item) => EcoIdea.fromJson(item))
            .toList();

        // Merge with local list to ensure no offline-created ideas are lost
        final localList = await _getLocalIdeas();
        final Map<String, EcoIdea> merged = {};
        for (final item in onlineList) {
          merged[item.id] = item;
        }
        for (final item in localList) {
          if (!merged.containsKey(item.id)) {
            merged[item.id] = item;
          }
        }

        final combined = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        await _saveLocalList(combined);
        return combined;
      }
    } catch (e) {
      debugPrint('EcoIdeasService: Fetching from local cache. Reason: $e');
    }

    // 2. Fallback to local cache
    return _getLocalIdeas();
  }

  // ── Local Storage Helpers ──────────────────────────────────────────────────

  Future<void> _saveLocalIdea(EcoIdea idea) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await _getLocalIdeas();
      list.insert(0, idea);
      await _saveLocalList(list, prefs: prefs);
    } catch (e) {
      debugPrint('EcoIdeasService: Error saving locally: $e');
    }
  }

  Future<void> _saveLocalList(List<EcoIdea> list, {SharedPreferences? prefs}) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final jsonList = list.map((item) => jsonEncode(item.toJson())).toList();
      await p.setStringList(_prefKeyEcoIdeas, jsonList);
    } catch (e) {
      debugPrint('EcoIdeasService: Error saving list locally: $e');
    }
  }

  Future<List<EcoIdea>> _getLocalIdeas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = prefs.getStringList(_prefKeyEcoIdeas) ?? [];
      return stringList
          .map((str) => EcoIdea.fromJson(jsonDecode(str) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('EcoIdeasService: Error reading local list: $e');
      return [];
    }
  }
}
