"""Compose the game's music and sound effects (no samples, no downloads).

Writes WAV files into assets/audio/:
  music_loop.wav    calm menu/map theme (kulintang gongs, agung, shaker)
  music_battle.wav  fast quiz-battle theme (war drums, gong ostinato)
  sfx_click.wav, sfx_correct.wav, sfx_wrong.wav, sfx_win.wav,
  sfx_slash.wav, sfx_hit.wav

Run from the project root:  python3 tools/make_audio.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(n, attack=0.005, decay=0.4):
    t = np.arange(n) / RATE
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def gong(freq, seconds=1.2, decay=0.45, bright=0.5):
    """Kulintang-like gong: a sine with slightly inharmonic overtones."""
    t = t_axis(seconds)
    tone = (np.sin(2 * np.pi * freq * t)
            + bright * 0.5 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t / (decay * 0.5))
            + bright * 0.25 * np.sin(2 * np.pi * freq * 3.03 * t) * np.exp(-t / (decay * 0.3)))
    return tone * env(len(t), 0.003, decay)


def agung(freq=73.4, seconds=2.0):
    """Big low hanging gong with a slow wobble."""
    t = t_axis(seconds)
    wob = 1 + 0.004 * np.sin(2 * np.pi * 3 * t)
    tone = np.sin(2 * np.pi * freq * wob * t) + 0.3 * np.sin(2 * np.pi * freq * 2.4 * t)
    return tone * env(len(t), 0.01, 0.9)


def drum(freq=110, seconds=0.5, decay=0.12, noise=0.25):
    """Pitched war drum: falling sine plus a slap of noise."""
    t = t_axis(seconds)
    f = freq * (1 + 1.5 * np.exp(-t / 0.03))
    body = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    slap = rng.standard_normal(len(t)) * np.exp(-t / 0.02) * noise
    return (body + slap) * env(len(t), 0.001, decay)


def shaker(seconds=0.12, level=0.25):
    t = t_axis(seconds)
    n = rng.standard_normal(len(t))
    n = np.diff(n, prepend=0)  # brighter
    return n * env(len(t), 0.004, 0.03) * level


def mix_into(track, sound, at, gain=1.0):
    i = int(at * RATE)
    if i >= len(track):
        return
    end = min(len(track), i + len(sound))
    track[i:end] += sound[:end - i] * gain


def wrap_tail(track, loop_len):
    """Fold the ring-out past the loop end back to the start (seamless loop)."""
    n = int(loop_len * RATE)
    out = track[:n].copy()
    tail = track[n:]
    out[:len(tail)] += tail
    return out


def note(name):
    """Note name like 'D4' -> Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]] + (1 if "#" in name else 0) + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semis / 12)


def main_theme():
    bpm = 92
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    track = np.zeros(int((length + 3) * RATE))
    # D major pentatonic melody, two 8-bar phrases (None = rest)
    phrase_a = ["D5", "E5", "F#5", "A5", None, "A5", "F#5", "E5",
                "D5", None, "B4", "D5", "E5", None, None, None,
                "F#5", "A5", "B5", "A5", "F#5", None, "E5", "D5",
                "E5", "F#5", "E5", "D5", "B4", None, None, None]
    phrase_b = ["A4", "B4", "D5", "E5", None, "F#5", "E5", "D5",
                "B4", None, "A4", "B4", "D5", None, None, None,
                "E5", "F#5", "A5", "F#5", "E5", None, "D5", "B4",
                "D5", "E5", "D5", "B4", "D5", None, None, None]
    melody = phrase_a + phrase_b + phrase_a + phrase_b
    # spread the 128 melody notes evenly over the 16 bars (quarter notes)
    step = length / len(melody)
    for i, n in enumerate(melody):
        if n:
            mix_into(track, gong(note(n), 1.4, 0.45, 0.6), i * step, 0.2)
    # accompaniment: soft gong pattern on the off-beats, chord roots per bar
    roots = ["D4", "D4", "B3", "A3", "D4", "G3", "A3", "A3"] * 2
    for bar, r in enumerate(roots):
        base = bar * 4 * beat
        mix_into(track, agung(note(r) / 4 * 2, 2.5), base, 0.35)
        for k in (1, 3):
            mix_into(track, gong(note(r), 0.8, 0.25, 0.3), base + k * beat, 0.09)
        for k in range(8):
            mix_into(track, shaker(level=0.18 if k % 2 else 0.1), base + k * beat / 2, 0.5)
    return wrap_tail(track, length) * 0.9


def battle_theme():
    bpm = 140
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    track = np.zeros(int((length + 3) * RATE))
    step = beat / 4  # sixteenths
    # D minor pentatonic kulintang ostinato, 2 bars, then a variation
    ost_a = ["D5", None, "F5", "D5", "G5", None, "F5", None, "A5", None, "G5", "F5", "D5", None, "C5", None,
             "D5", None, "F5", "D5", "G5", None, "A5", None, "C6", None, "A5", "G5", "F5", None, "G5", None]
    ost_b = ["A5", None, "C6", "A5", "G5", None, "F5", None, "G5", None, "F5", "D5", "C5", None, "D5", None,
             "F5", None, "G5", "F5", "D5", None, "C5", None, "D5", None, None, None, "D5", "D5", "D5", None]
    pattern = (ost_a * 2 + ost_b + ost_a) * 2
    for i, n in enumerate(pattern):
        if n:
            mix_into(track, gong(note(n), 0.5, 0.16, 0.7), i * step, 0.16)
    roots = ["D3", "D3", "A#2", "C3", "D3", "D3", "F3", "A2"] * 2
    for bar, r in enumerate(roots):
        base = bar * 4 * beat
        # war drums: boom - - boom | boom - boom boom (eighths)
        for k, g in [(0, 1.0), (3, 0.6), (4, 0.9), (6, 0.7), (7, 0.8)]:
            mix_into(track, drum(70, 0.5, 0.18, 0.2), base + k * beat / 2, 0.55 * g)
        for k in (2, 6):  # snare-ish slap on 2 and 4
            mix_into(track, drum(220, 0.25, 0.06, 0.9), base + k * beat / 2, 0.3)
        for k in range(16):
            mix_into(track, shaker(0.08, 0.2 if k % 4 == 2 else 0.1), base + k * step, 0.5)
        # pulsing bass gong
        for k in range(4):
            mix_into(track, gong(note(r), 0.5, 0.2, 0.2), base + k * beat, 0.2)
        if bar % 4 == 0:
            mix_into(track, agung(note(r), 2.0), base, 0.35)
    return wrap_tail(track, length) * 0.85


def sfx_click():
    t = t_axis(0.09)
    tone = np.sin(2 * np.pi * 1320 * t) + 0.4 * np.sin(2 * np.pi * 2650 * t)
    return tone * env(len(t), 0.001, 0.02) * 0.6


def sfx_correct():
    out = np.zeros(int(0.7 * RATE))
    for i, n in enumerate(["D5", "F#5", "A5", "D6"]):
        mix_into(out, gong(note(n), 0.6, 0.18, 0.5), i * 0.07, 0.35)
    return out


def sfx_wrong():
    t = t_axis(0.5)
    f = 220 * np.exp(-t * 1.2)
    tone = np.sign(np.sin(2 * np.pi * np.cumsum(f) / RATE)) * 0.4 + np.sin(2 * np.pi * np.cumsum(f * 0.5) / RATE)
    return tone * env(len(t), 0.005, 0.18) * 0.35


def sfx_win():
    out = np.zeros(int(2.2 * RATE))
    seq = ["D5", "E5", "F#5", "A5", "B5", "A5", "D6"]
    for i, n in enumerate(seq):
        mix_into(out, gong(note(n), 1.0, 0.35 if i == len(seq) - 1 else 0.2, 0.6), i * 0.11, 0.3)
    mix_into(out, agung(73.4, 2.0), 0.66, 0.5)
    return out


def sfx_slash():
    t = t_axis(0.35)
    n = rng.standard_normal(len(t))
    # band-limited whoosh sweeping up: crude moving filter via cumulative mix
    sweep = np.sin(2 * np.pi * np.cumsum(600 + 3000 * t / t[-1]) / RATE)
    whoosh = n * (0.5 + 0.5 * sweep)
    shape = np.sin(np.pi * np.clip(t / 0.25, 0, 1)) ** 2
    return whoosh * shape * 0.35


def sfx_hit():
    out = drum(90, 0.4, 0.1, 0.8) * 0.8
    t = t_axis(0.4)
    clang = (np.sin(2 * np.pi * 1450 * t) + np.sin(2 * np.pi * 2210 * t)) * env(len(t), 0.001, 0.07)
    return out + clang * 0.2


def write(name, data):
    data = np.asarray(data, dtype=float)
    peak = np.max(np.abs(data)) or 1.0
    if peak > 0.95:
        data = data / peak * 0.95
    pcm = (data * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print("wrote", os.path.normpath(path), "%.1fs" % (len(pcm) / RATE))


if __name__ == "__main__":
    write("music_loop.wav", main_theme())
    write("music_battle.wav", battle_theme())
    write("sfx_click.wav", sfx_click())
    write("sfx_correct.wav", sfx_correct())
    write("sfx_wrong.wav", sfx_wrong())
    write("sfx_win.wav", sfx_win())
    write("sfx_slash.wav", sfx_slash())
    write("sfx_hit.wav", sfx_hit())
