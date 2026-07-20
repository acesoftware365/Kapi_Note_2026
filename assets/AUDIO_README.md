# Kapi Note game audio

This folder contains original, locally generated audio for Kapi Note. The
files do not depend on network access or third-party media licenses.

## Music

- `music_for_game/menu_theme_loop.wav`: calm menu loop.
- `music_for_game/gameplay_loop.wav`: restrained gameplay loop.
- `music_for_game/results_theme.wav`: results screen loop.
- `music_for_game/victory_music.wav`: short victory cue.
- `music_for_game/defeat_music.wav`: short defeat cue.

## Sound effects

The `sfx_for_game` folder contains button, domino, score, timer, result,
player, and message cues. File names are exposed through
`lib/constants/audio_assets.dart` so screens do not use raw paths.

## Regenerating

Run the generator from the project root:

```sh
python3 tool/generate_game_audio.py
```

The generator uses Python's standard library and writes mono, 16-bit,
44.1 kHz WAV files. It is safe to run repeatedly because it replaces only
the generated audio files with the same names.

## Flutter usage

Initialize the singleton once before `runApp`, then use constants:

```dart
await AudioManager.instance.initialize();
await AudioManager.instance.playSfx(AudioAssets.dominoPlace);
await AudioManager.instance.playMusic(AudioAssets.gameplayLoop);
```

Music and SFX preferences and volumes are stored independently. Use the
Audio Test entry in Settings to verify every file on a real device.
