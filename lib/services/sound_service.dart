import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  bool _isMusicEnabled = true;

  bool get isMusicEnabled => _isMusicEnabled;

  static const String _kPrefBgmKey = 'eco_avengers_bgm_enabled';
  static const String _kSongAsset = 'assets/song.mp3';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool(_kPrefBgmKey) ?? true;

      await _player.setAsset(_kSongAsset);
      await _player.setLoopMode(LoopMode.all);
      await _player.setVolume(0.6);

      _isInitialized = true;

      if (_isMusicEnabled) {
        _player.play();
      }
    } catch (e) {
      debugPrint('SoundService init error: $e');
    }
  }

  Future<void> toggleMusic() async {
    await setMusicEnabled(!_isMusicEnabled);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefBgmKey, enabled);

      if (!_isInitialized) {
        init();
        return;
      }

      if (_isMusicEnabled) {
        if (!_player.playing) {
          _player.play();
        }
      } else {
        if (_player.playing) {
          await _player.pause();
        }
      }
    } catch (e) {
      debugPrint('SoundService setMusicEnabled error: $e');
    }
  }

  Future<void> play() async {
    if (!_isMusicEnabled) return;
    try {
      if (!_isInitialized) {
        init();
      } else if (!_player.playing) {
        _player.play();
      }
    } catch (e) {
      debugPrint('SoundService play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      if (_player.playing) {
        await _player.pause();
      }
    } catch (e) {
      debugPrint('SoundService pause error: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
