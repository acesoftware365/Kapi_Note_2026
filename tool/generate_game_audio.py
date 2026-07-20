#!/usr/bin/env python3
"""Generate Kapi Note's original synthesized game music and SFX WAV files."""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44_100
ROOT = Path(__file__).resolve().parents[1]
MUSIC_DIR = ROOT / "assets" / "music_for_game"
SFX_DIR = ROOT / "assets" / "sfx_for_game"
TAU = math.tau


def clamp(value):
    return max(-1.0, min(1.0, value))


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max((abs(sample) for sample in samples), default=1.0)
    gain = min(0.82 / peak, 1.0)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(
            b"".join(
                struct.pack("<h", int(clamp(sample * gain) * 32767))
                for sample in samples
            )
        )


def envelope(t, duration, attack=0.012, release=0.12):
    return min(1.0, t / max(attack, 0.001), (duration - t) / max(release, 0.001))


def tone(freq, duration, volume=0.4, wave_kind="sine", slide=0.0):
    samples = []
    phase = 0.0
    for index in range(int(RATE * duration)):
        t = index / RATE
        current = freq + slide * (t / duration)
        phase += TAU * current / RATE
        if wave_kind == "triangle":
            value = 2 / math.pi * math.asin(math.sin(phase))
        elif wave_kind == "soft_square":
            value = math.tanh(1.7 * math.sin(phase)) * 0.72
        else:
            value = math.sin(phase)
        samples.append(value * volume * max(0.0, envelope(t, duration)))
    return samples


def mix(tracks, length=None):
    size = length or max((offset + len(samples) for offset, samples in tracks), default=0)
    output = [0.0] * size
    for offset, samples in tracks:
        for index, sample in enumerate(samples):
            if offset + index < size:
                output[offset + index] += sample
    return output


def noise(duration, volume=0.25, decay=5.0, seed=1):
    rng = random.Random(seed)
    return [
        rng.uniform(-1, 1) * volume * math.exp(-decay * index / RATE)
        for index in range(int(duration * RATE))
    ]


def sequence(notes, bpm, bars, mood=1.0):
    beat = 60.0 / bpm
    duration = bars * 4 * beat
    tracks = []
    bass = [notes[0] / 2, notes[2] / 2, notes[3] / 2, notes[1] / 2]
    for step in range(bars * 8):
        start = step * beat / 2
        note = notes[(step * 3 + step // 4) % len(notes)]
        pluck = tone(note, beat * 0.42, 0.16 * mood, "triangle", -2)
        tracks.append((int(start * RATE), pluck))
        if step % 2 == 0:
            low = tone(bass[(step // 2) % 4], beat * 0.78, 0.14, "sine")
            tracks.append((int(start * RATE), low))
        if step % 4 in (1, 3):
            click = noise(0.045, 0.055, 35, seed=step + bars)
            tracks.append((int(start * RATE), click))
    # A quiet sustained pad makes the loop boundary feel smooth.
    for bar in range(bars):
        root = notes[(bar // 2) % len(notes)] / 2
        for ratio in (1, 1.25, 1.5):
            pad = tone(root * ratio, 4 * beat, 0.032, "sine")
            tracks.append((int(bar * 4 * beat * RATE), pad))
    result = mix(tracks, int(duration * RATE))
    fade = int(0.28 * RATE)
    for index in range(fade):
        factor = index / fade
        result[index] *= factor
        result[-1 - index] *= factor
    return result


def effect_chime(notes, note_duration=0.12, volume=0.35):
    tracks = []
    cursor = 0
    for note in notes:
        part = tone(note, note_duration, volume, "triangle", -3)
        tracks.append((cursor, part))
        cursor += int(note_duration * 0.62 * RATE)
    return mix(tracks)


def create_music():
    music = {
        "menu_theme_loop.wav": sequence([261.63, 329.63, 392.00, 440.00], 92, 8, 0.92),
        "gameplay_loop.wav": sequence([293.66, 349.23, 440.00, 523.25], 108, 8, 0.86),
        "results_theme.wav": sequence([261.63, 392.00, 493.88, 329.63], 84, 6, 0.82),
        "victory_music.wav": effect_chime([392, 523.25, 659.25, 783.99, 1046.5], 0.34, 0.30),
        "defeat_music.wav": effect_chime([392, 349.23, 293.66, 246.94], 0.42, 0.25),
    }
    for name, samples in music.items():
        write_wav(MUSIC_DIR / name, samples)


def create_sfx():
    shuffle = mix([
        (int(i * 0.055 * RATE), noise(0.09, 0.15, 24, seed=40 + i))
        for i in range(8)
    ])
    sfx = {
        "button_tap.wav": mix([(0, tone(520, 0.06, 0.22, "triangle", -90)), (0, noise(0.025, 0.05, 50, 4))]),
        "domino_place.wav": mix([(0, noise(0.07, 0.30, 35, 8)), (0, tone(135, 0.10, 0.18, "sine", -20))]),
        "domino_shuffle.wav": shuffle,
        "domino_draw.wav": mix([(0, noise(0.11, 0.18, 16, 11)), (int(0.04 * RATE), tone(330, 0.10, 0.12, "triangle", 40))]),
        "domino_double.wav": mix([(0, tone(180, 0.12, 0.24, "sine", -20)), (int(0.075 * RATE), tone(180, 0.13, 0.22, "sine", -25))]),
        "score_increase.wav": effect_chime([523.25, 659.25], 0.13, 0.27),
        "score_decrease.wav": effect_chime([392, 293.66], 0.15, 0.24),
        "turn_notification.wav": effect_chime([440, 587.33], 0.11, 0.22),
        "countdown_tick.wav": mix([(0, tone(900, 0.055, 0.18, "sine")), (0, noise(0.018, 0.04, 70, 9))]),
        "timer_end.wav": effect_chime([330, 330, 220], 0.18, 0.26),
        "success.wav": effect_chime([523.25, 659.25, 783.99], 0.12, 0.28),
        "error.wav": mix([(0, tone(190, 0.22, 0.22, "soft_square", -35))]),
        "celebration.wav": effect_chime([392, 523.25, 659.25, 783.99], 0.16, 0.30),
        "game_start.wav": effect_chime([293.66, 392, 587.33], 0.17, 0.28),
        "game_over.wav": effect_chime([523.25, 392, 261.63], 0.22, 0.25),
        "round_win.wav": effect_chime([440, 554.37, 659.25, 880], 0.13, 0.29),
        "invalid_move.wav": mix([(0, tone(165, 0.09, 0.24, "soft_square")), (int(0.11 * RATE), tone(145, 0.12, 0.22, "soft_square"))]),
        "player_joined.wav": effect_chime([392, 493.88, 659.25], 0.11, 0.24),
        "player_left.wav": effect_chime([493.88, 392, 293.66], 0.13, 0.21),
        "message_received.wav": effect_chime([698.46, 880], 0.09, 0.20),
    }
    for name, samples in sfx.items():
        write_wav(SFX_DIR / name, samples)


def main():
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    create_music()
    create_sfx()
    print(f"Generated 5 music tracks in {MUSIC_DIR}")
    print(f"Generated 20 sound effects in {SFX_DIR}")


if __name__ == "__main__":
    main()
