import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioManager extends ChangeNotifier with WidgetsBindingObserver {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  static const _musicEnabledKey = 'musicEnabled';
  static const _sfxEnabledKey = 'sfxEnabled';
  static const _musicVolumeKey = 'musicVolume';
  static const _sfxVolumeKey = 'sfxVolume';

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _initialized = false;
  bool _pausedByLifecycle = false;
  bool musicEnabled = true;
  bool sfxEnabled = true;
  double musicVolume = 0.45;
  double sfxVolume = 0.80;
  String? currentMusic;
  bool musicPaused = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    sfxEnabled = prefs.getBool(_sfxEnabledKey) ?? true;
    musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.45;
    sfxVolume = prefs.getDouble(_sfxVolumeKey) ?? 0.80;
    // AudioContext is a mobile audio-session concept. Applying the Android
    // context to the Darwin desktop player can leave AVPlayer prepared but
    // silent on macOS, so configure it only where it is actually supported.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final audioContext = AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          audioMode: AndroidAudioMode.normal,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      );
      await AudioPlayer.global.setAudioContext(audioContext);
      await _musicPlayer.setAudioContext(audioContext);
      await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
    } else {
      await _musicPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _sfxPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    }
    await _musicPlayer.setVolume(musicVolume);
    await _sfxPlayer.setVolume(sfxVolume);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    await initialize();
    if (!musicEnabled) return;
    try {
      if (currentMusic == assetPath && musicPaused) {
        await resumeMusic();
        return;
      }
      if (currentMusic != assetPath) await _musicPlayer.stop();
      currentMusic = assetPath;
      musicPaused = false;
      await _musicPlayer.setReleaseMode(
        loop ? ReleaseMode.loop : ReleaseMode.release,
      );
      await _musicPlayer.play(AssetSource(assetPath), volume: musicVolume);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (musicEnabled &&
          currentMusic == assetPath &&
          _musicPlayer.state != PlayerState.playing) {
        await _musicPlayer.stop();
        await _musicPlayer.setReleaseMode(
          loop ? ReleaseMode.loop : ReleaseMode.release,
        );
        await _musicPlayer.play(AssetSource(assetPath), volume: musicVolume);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Kapi audio music error: $error');
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
      musicPaused = true;
      notifyListeners();
    } catch (error) {
      debugPrint('Kapi audio pause error: $error');
    }
  }

  Future<void> resumeMusic() async {
    if (!musicEnabled || currentMusic == null) return;
    try {
      await _musicPlayer.resume();
      musicPaused = false;
      notifyListeners();
    } catch (error) {
      debugPrint('Kapi audio resume error: $error');
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
    currentMusic = null;
    musicPaused = false;
    notifyListeners();
  }

  Future<void> playSfx(String assetPath) async {
    await initialize();
    if (!sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource(assetPath), volume: sfxVolume);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (sfxEnabled && _sfxPlayer.state != PlayerState.playing) {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(AssetSource(assetPath), volume: sfxVolume);
      }
    } catch (error) {
      debugPrint('Kapi audio SFX error: $error');
    }
  }

  Future<void> stopSfx() => _sfxPlayer.stop();

  Future<void> stopAll() async {
    await Future.wait([stopMusic(), stopSfx()]);
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0, 1);
    await _musicPlayer.setVolume(musicVolume);
    await _saveDouble(_musicVolumeKey, musicVolume);
    notifyListeners();
  }

  Future<void> setSfxVolume(double value) async {
    sfxVolume = value.clamp(0, 1);
    await _sfxPlayer.setVolume(sfxVolume);
    await _saveDouble(_sfxVolumeKey, sfxVolume);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, value);
    if (!value) await stopMusic();
    notifyListeners();
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxEnabledKey, value);
    if (!value) await stopSfx();
    notifyListeners();
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldPause =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS));
    if (shouldPause) {
      if (currentMusic != null && !musicPaused) {
        _pausedByLifecycle = true;
        unawaited(pauseMusic());
      }
    } else if (state == AppLifecycleState.resumed && _pausedByLifecycle) {
      _pausedByLifecycle = false;
      unawaited(resumeMusic());
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
    super.dispose();
  }
}
