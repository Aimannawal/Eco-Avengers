import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _prefUsername = 'player_username';
  static const String _prefAvatarUrl = 'player_avatar_url';

  // Hashing helper
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if currently logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefUsername);
  }

  // Get current username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefUsername);
  }

  // Get current avatar url
  Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefAvatarUrl);
  }

  // Register a new player
  Future<Map<String, dynamic>> register({
    required String username,
    required String pin,
    required String displayName,
  }) async {
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      final pinHash = _hashPin(pin);

      final response = await SupabaseService.instance.client.rpc(
        'register_player',
        params: {
          'p_player_id': playerId,
          'p_username': username,
          'p_pin_hash': pinHash,
          'p_display_name': displayName,
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw 'Koneksi ke server timeout (Supabase mungkin sedang sleep/offline). Silakan coba lagi.';
      });

      Map<String, dynamic> result;
      if (response is List && response.isNotEmpty) {
        result = Map<String, dynamic>.from(response.first);
      } else {
        result = Map<String, dynamic>.from(response as Map);
      }

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefUsername, username);
        await SupabaseService.instance.savePlayerName(displayName);
        // Also ensure playerId is stored if not already
        if (result['player_id'] != null) {
          await prefs.setString('player_id', result['player_id'].toString());
        } else {
          await prefs.setString('player_id', playerId);
        }
        return {'success': true};
      } else {
        return {'success': false, 'error': result['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  // Login player
  Future<Map<String, dynamic>> login({
    required String username,
    required String pin,
  }) async {
    try {
      final pinHash = _hashPin(pin);

      final response = await SupabaseService.instance.client.rpc(
        'login_player',
        params: {
          'p_username': username,
          'p_pin_hash': pinHash,
        },
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw 'Koneksi ke server timeout (Supabase mungkin sedang sleep/offline). Silakan coba lagi.';
      });

      Map<String, dynamic> result;
      if (response is List && response.isNotEmpty) {
        result = Map<String, dynamic>.from(response.first);
      } else {
        result = Map<String, dynamic>.from(response as Map);
      }

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefUsername, username);
        if (result['display_name'] != null) {
          await SupabaseService.instance.savePlayerName(result['display_name'].toString());
        }
        if (result['player_id'] != null) {
          await prefs.setString('player_id', result['player_id'].toString());
        }
        if (result['avatar_url'] != null) {
          await prefs.setString(_prefAvatarUrl, result['avatar_url'].toString());
        }
        return {'success': true};
      } else {
        return {'success': false, 'error': result['error']};
      }
    } catch (e) {
      return {'success': false, 'error': 'Login failed: $e'};
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUsername);
    await prefs.remove(_prefAvatarUrl);
    // Don't remove player_id so anonymous data still works,
    // or remove it if you want strict logout. Let's keep it to allow seamless offline play.
  }

  // Upload Avatar
  Future<String?> uploadAvatar(File file) async {
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      print('[AVATAR] playerId: $playerId');

      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '$playerId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      print('[AVATAR] Uploading to path: $fileName');

      final client = SupabaseService.instance.client;

      // Upload file to storage
      try {
        await client.storage.from('avatar').upload(
          fileName,
          file,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: 'image/$ext',
          ),
        );
        print('[AVATAR] Upload SUCCESS');
      } catch (uploadErr) {
        print('[AVATAR] Upload FAILED: $uploadErr');
        rethrow;
      }

      // Get public URL
      final publicUrl = client.storage.from('avatar').getPublicUrl(fileName);
      print('[AVATAR] Public URL: $publicUrl');

      // Update di Supabase Database
      try {
        await client
            .from('player_profiles')
            .update({'avatar_url': publicUrl})
            .eq('player_id', playerId);
        print('[AVATAR] DB update SUCCESS');
      } catch (dbErr) {
        print('[AVATAR] DB update FAILED: $dbErr');
        // Still return publicUrl even if DB update fails, 
        // but maybe we shouldn't if we want consistency.
      }

      // Update Local Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAvatarUrl, publicUrl);

      return publicUrl;
    } catch (e) {
      print('[AVATAR] FATAL error: $e');
      return null;
    }
  }

  // Update Profile Data
  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    String? country,
    String? bio,
  }) async {
    try {
      final playerId = await SupabaseService.instance.getOrCreatePlayerId();
      await SupabaseService.instance.client
          .from('player_profiles')
          .update({
            'display_name': displayName,
            'country': country,
            'bio': bio,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('player_id', playerId);
      
      // Update local storage
      await SupabaseService.instance.savePlayerName(displayName);
      
      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': 'Failed to update profile: $e'};
    }
  }
}
