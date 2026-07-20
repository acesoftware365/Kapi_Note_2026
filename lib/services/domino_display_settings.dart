import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DominoDisplaySettings {
  static const _playedTileScaleKey = 'domino_played_tile_scale';
  static const _handTileScaleKey = 'domino_hand_tile_scale';
  static const double minPlayedTileScale = 0.9;
  static const double maxPlayedTileScale = 1.3;
  static const double minHandTileScale = 0.9;
  static const double maxHandTileScale = 1.3;
  static final ValueNotifier<double> playedTileScale = ValueNotifier(1.0);
  static final ValueNotifier<double> handTileScale = ValueNotifier(1.0);

  static Future<double> loadPlayedTileScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = (preferences.getDouble(_playedTileScaleKey) ?? 1.0).clamp(
      minPlayedTileScale,
      maxPlayedTileScale,
    );
    playedTileScale.value = value;
    return value;
  }

  static Future<void> savePlayedTileScale(double value) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = value.clamp(minPlayedTileScale, maxPlayedTileScale);
    playedTileScale.value = normalized;
    await preferences.setDouble(_playedTileScaleKey, normalized);
  }

  static Future<double> loadHandTileScale() async {
    final preferences = await SharedPreferences.getInstance();
    final value = (preferences.getDouble(_handTileScaleKey) ?? 1.0).clamp(
      minHandTileScale,
      maxHandTileScale,
    );
    handTileScale.value = value;
    return value;
  }

  static Future<void> saveHandTileScale(double value) async {
    final preferences = await SharedPreferences.getInstance();
    final normalized = value.clamp(minHandTileScale, maxHandTileScale);
    handTileScale.value = normalized;
    await preferences.setDouble(_handTileScaleKey, normalized);
  }
}
