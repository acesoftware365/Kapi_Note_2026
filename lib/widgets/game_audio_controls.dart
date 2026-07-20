import 'package:flutter/material.dart';

import '../constants/audio_assets.dart';
import '../services/audio_manager.dart';

class GameAudioControls extends StatelessWidget {
  const GameAudioControls({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.instance;
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        if (compact) {
          return Row(
            children: [
              Expanded(
                child: _QuickAudioButton(
                  icon:
                      audio.musicEnabled
                          ? Icons.music_note_rounded
                          : Icons.music_off_rounded,
                  label: spanish ? 'Musica' : 'Music',
                  enabled: audio.musicEnabled,
                  onPressed: () async {
                    final enable = !audio.musicEnabled;
                    await audio.setMusicEnabled(enable);
                    if (enable) {
                      await audio.playMusic(AudioAssets.gameplayLoop);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAudioButton(
                  icon:
                      audio.sfxEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                  label: spanish ? 'Efectos' : 'SFX',
                  enabled: audio.sfxEnabled,
                  onPressed: () => audio.setSfxEnabled(!audio.sfxEnabled),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            SwitchListTile.adaptive(
              secondary: Icon(
                audio.musicEnabled
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
              ),
              title: Text(spanish ? 'Musica del juego' : 'Game music'),
              subtitle: Text('${(audio.musicVolume * 100).round()}%'),
              value: audio.musicEnabled,
              onChanged: (enabled) async {
                await audio.setMusicEnabled(enabled);
                if (enabled) {
                  await audio.playMusic(AudioAssets.gameplayLoop);
                }
              },
            ),
            Slider(
              value: audio.musicVolume,
              divisions: 10,
              label: '${(audio.musicVolume * 100).round()}%',
              onChanged: audio.musicEnabled ? audio.setMusicVolume : null,
            ),
            SwitchListTile.adaptive(
              secondary: Icon(
                audio.sfxEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
              title: Text(spanish ? 'Efectos del juego' : 'Game effects'),
              subtitle: Text('${(audio.sfxVolume * 100).round()}%'),
              value: audio.sfxEnabled,
              onChanged: audio.setSfxEnabled,
            ),
            Slider(
              value: audio.sfxVolume,
              divisions: 10,
              label: '${(audio.sfxVolume * 100).round()}%',
              onChanged: audio.sfxEnabled ? audio.setSfxVolume : null,
            ),
          ],
        );
      },
    );
  }
}

class _QuickAudioButton extends StatelessWidget {
  const _QuickAudioButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text('${enabled ? 'On' : 'Off'} - $label'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color:
              enabled
                  ? const Color(0xFFFFD36B)
                  : Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
