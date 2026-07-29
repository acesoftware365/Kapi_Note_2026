import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/audio_assets.dart';
import '../services/audio_manager.dart';

class AudioTestScreen extends StatelessWidget {
  const AudioTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioManager.instance;
    return AnimatedBuilder(
      animation: audio,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Audio Test'),
              actions: [
                IconButton(
                  onPressed: audio.stopAll,
                  tooltip: 'Stop All',
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AudioControls(audio: audio),
                if (!kReleaseMode) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Music',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final entry in AudioAssets.music.entries)
                    _MusicRow(name: entry.key, path: entry.value, audio: audio),
                ],
                const SizedBox(height: 18),
                Text(
                  'Sound Effects',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                for (final entry in AudioAssets.soundEffects.entries)
                  _SfxRow(name: entry.key, path: entry.value, audio: audio),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: audio.stopAll,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop All'),
                ),
              ],
            ),
          ),
    );
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({required this.audio});

  final AudioManager audio;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (!kReleaseMode) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Music'),
                subtitle: Text('${(audio.musicVolume * 100).round()}%'),
                value: audio.musicEnabled,
                onChanged: audio.setMusicEnabled,
              ),
              Slider(
                value: audio.musicVolume,
                label: '${(audio.musicVolume * 100).round()}%',
                onChanged: audio.musicEnabled ? audio.setMusicVolume : null,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sound Effects'),
              subtitle: Text('${(audio.sfxVolume * 100).round()}%'),
              value: audio.sfxEnabled,
              onChanged: audio.setSfxEnabled,
            ),
            Slider(
              value: audio.sfxVolume,
              label: '${(audio.sfxVolume * 100).round()}%',
              onChanged: audio.sfxEnabled ? audio.setSfxVolume : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicRow extends StatelessWidget {
  const _MusicRow({
    required this.name,
    required this.path,
    required this.audio,
  });

  final String name;
  final String path;
  final AudioManager audio;

  @override
  Widget build(BuildContext context) {
    final active = audio.currentMusic == path;
    return Card(
      color: active ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (AudioAssets.loops(path)) const Chip(label: Text('Loop')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                IconButton.filledTonal(
                  onPressed:
                      () =>
                          audio.playMusic(path, loop: AudioAssets.loops(path)),
                  tooltip: 'Play $name',
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                IconButton.filledTonal(
                  onPressed: active ? audio.pauseMusic : null,
                  tooltip: 'Pause',
                  icon: const Icon(Icons.pause_rounded),
                ),
                IconButton.filledTonal(
                  onPressed: active ? audio.resumeMusic : null,
                  tooltip: 'Resume',
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
                IconButton.filledTonal(
                  onPressed: active ? audio.stopMusic : null,
                  tooltip: 'Stop',
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SfxRow extends StatelessWidget {
  const _SfxRow({required this.name, required this.path, required this.audio});

  final String name;
  final String path;
  final AudioManager audio;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.surround_sound_rounded),
        title: Text(name),
        trailing: IconButton.filledTonal(
          onPressed: () => audio.playSfx(path),
          tooltip: 'Play $name',
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ),
    );
  }
}
