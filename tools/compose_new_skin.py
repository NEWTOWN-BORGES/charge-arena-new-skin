"""The new skin's soundtrack: two bright, bouncy loops to go with the rubber look, made from
scratch with the synths of tools/compose_music.py (no samples, no licences).

    python tools/compose_new_skin.py [menu] [match]

Writes audio/polished/music_menu.ogg ("Ilha de Borracha", 100 BPM, F major) and
audio/polished/music_match.ogg ("Borracha Turbo", 128 BPM, C major). Loops without a seam.
Needs numpy, scipy and ffmpeg (libvorbis) on PATH.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_music as cm  # noqa: E402
from compose_music import Track, bell, finish, hat, kick, pad, pluck, snare, sub_bass, bass_note, lead, swell, filt, noise, SR  # noqa: E402


def place(name):
    """finish() writes audio/<name>_new.ogg; the game plays audio/polished/<name>.ogg."""
    root = os.path.join(cm.ROOT, "audio")
    os.replace(os.path.join(root, name + "_new.ogg"), os.path.join(root, "polished", name + ".ogg"))


def marimba(note, length=0.5):
    """A round, woody mallet: two sine partials with a fast knock, the rubber of the game."""
    n = int(SR * length)
    t = np.arange(n) / SR
    f = cm.hz(note)
    body = np.sin(2 * np.pi * f * t) * np.exp(-t * 7.0)
    overtone = np.sin(2 * np.pi * f * 3.9 * t) * np.exp(-t * 26.0) * 0.35
    knock = np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 90.0) * 0.15
    return (body + overtone + knock) * 0.9


def boing(note, length=0.28):
    """A springy bass: the pitch bends down into the note, like a rubber ball landing."""
    n = int(SR * length)
    t = np.arange(n) / SR
    f = cm.hz(note) * (1.0 + 0.35 * np.exp(-t * 40.0))
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.3 * np.sin(2 * phase)
    return tone * np.exp(-t * 6.0) * np.clip(t / 0.003, 0, 1)


def clap(level=1.0):
    n = int(SR * 0.18)
    t = np.arange(n) / SR
    burst = np.zeros(n)
    for delay in (0.0, 0.009, 0.018):
        k = int(delay * SR)
        burst[k:] += np.exp(-(t[: n - k]) * 60.0)
    return filt(noise(n), "band", 1500, 0.9) * burst * level


def shaker(level=1.0):
    n = int(SR * 0.06)
    t = np.arange(n) / SR
    return filt(noise(n), "high", 6500) * np.exp(-t * 70.0) * level


def ilha_de_borracha():
    """Menu: F major, sunny and unhurried; a marimba arpeggio, bells singing over it."""
    track = Track(100, 16)
    track.rt60, track.damping, track.feedback, track.echo_tone = 2.6, 5200, 0.35, 3400
    beat = track.beat / SR
    chords = [([53, 57, 60, 65], 41), ([50, 53, 57, 62], 38), ([46, 50, 53, 58], 34), ([48, 52, 55, 60], 36)]
    for bar_index in range(16):
        notes, root = chords[(bar_index // 2) % 4]
        start = track.at(bar_index)
        if bar_index % 2 == 0:
            track.add(pad(notes, beat * 8, 3200, 0.1), start, 0.22, verb=0.45)
            track.add(sub_bass(root, beat * 7.6), start, 0.2)
        # Bouncing bass on the one and the and-of-two.
        for b, jump in ((0, 0), (1.5, 12), (2.5, 7), (3.5, 12)):
            track.add(boing(root + 12 + jump, 0.3), track.at(bar_index, b), 0.22)
        tones = [n + 12 for n in notes]
        for step, pick in enumerate([0, 2, 1, 3, 2, 1, 3, 2]):
            accent = 1.0 if step % 4 == 0 else 0.7
            track.add(marimba(tones[pick], 0.6), start + step * track.beat // 2, 0.16 * accent,
                      pan=-0.3 if step % 2 == 0 else 0.3, verb=0.3, echo=0.2)
        if bar_index >= 4:
            for b in (0, 2):
                track.add(kick(soft=True), track.at(bar_index, b), 0.42)
            for b in (1, 3):
                track.add(clap(), track.at(bar_index, b), 0.16, verb=0.3)
            for b in (0.5, 1.5, 2.5, 3.5):
                track.add(shaker(), track.at(bar_index, b), 0.06, pan=0.35)
    melody = [(8, 0, 77, 1.5), (8, 1.5, 79, 0.5), (8, 2, 81, 2), (9, 0, 77, 2), (9, 2, 74, 2),
              (10, 0, 74, 1), (10, 1, 77, 1), (10, 2, 82, 2), (11, 0, 81, 3), (11, 3, 79, 1),
              (12, 0, 77, 1.5), (12, 1.5, 79, 0.5), (12, 2, 81, 1), (12, 3, 84, 1), (13, 0, 82, 2), (13, 2, 81, 2),
              (14, 0, 79, 2), (14, 2, 77, 1), (14, 3, 76, 1), (15, 0, 77, 4)]
    for bar_index, b, note, beats in melody:
        track.add(bell(note, beats * beat), track.at(bar_index, b), 0.1, pan=0.1, verb=0.5, echo=0.3)
    track.add(swell(beat * 4, 500, 6000), track.at(3), 0.05, verb=0.4)
    finish(track, "music_menu_new", -18.0, 0.45, 0.3)
    place("music_menu")


def borracha_turbo():
    """Match: C major at 128, four on the floor, bouncing octave bass, marimba hook, a lead."""
    track = Track(128, 32)
    track.rt60, track.damping, track.feedback, track.echo_tone = 1.6, 6000, 0.32, 3600
    beat = track.beat / SR
    chords = [([48, 52, 55, 60], 36), ([43, 47, 50, 55], 43), ([45, 48, 52, 57], 45), ([41, 45, 48, 53], 41)]
    pads = Track(128, 32)
    basses = Track(128, 32)
    for bar_index in range(32):
        notes, root = chords[(bar_index // 2) % 4]
        start = track.at(bar_index)
        section = bar_index // 8
        if bar_index % 2 == 0:
            pads.add(pad([n + 12 for n in notes], beat * 8, 4200, 0.1), start, 1.0, verb=0.3)
        for step in range(8):
            jump = 12 if step % 2 else 0
            basses.add(boing(root + 12 + jump, beat * 0.45), start + step * track.beat // 2, 0.5 if step % 2 == 0 else 0.4)
        if section >= 1:
            tones = [n + 24 for n in notes]
            hook = [0, 2, 3, 2, 1, 2, 3, 1]
            for step, pick in enumerate(hook):
                track.add(marimba(tones[pick], 0.4), start + step * track.beat // 2, 0.14,
                          pan=-0.35 if step % 2 == 0 else 0.35, verb=0.2, echo=0.25)
        for b in range(4):
            track.add(kick(), track.at(bar_index, b), 0.8)
        if bar_index >= 4:
            for b in (1, 3):
                track.add(clap(), track.at(bar_index, b), 0.3, verb=0.2)
                track.add(snare(0.6), track.at(bar_index, b), 0.18)
        for b in (0.5, 1.5, 2.5, 3.5):
            track.add(hat(), track.at(bar_index, b), 0.12, pan=0.25)
        if section >= 2:
            for b in (0.25, 0.75, 1.25, 1.75, 2.25, 2.75, 3.25, 3.75):
                track.add(shaker(), track.at(bar_index, b), 0.05, pan=-0.3)
    pad_curve = pads.pump(0.55)
    bass_curve = basses.pump(0.35, 0.12)
    track.dry += pads.dry * pad_curve * 0.7 + basses.dry * bass_curve * 0.5
    track.verb += pads.verb * pad_curve * 0.7
    phrase = [(0, 72, 1), (1, 76, 1), (2, 79, 1.5), (3.5, 76, 0.5), (4, 77, 1), (5, 76, 1), (6, 74, 2),
              (8, 72, 1), (9, 76, 1), (10, 79, 1), (11, 84, 1), (12, 81, 2), (14, 79, 2),
              (16, 77, 1), (17, 76, 1), (18, 74, 1), (19, 76, 1), (20, 79, 2), (22, 76, 2),
              (24, 74, 1), (25, 72, 1), (26, 71, 1), (27, 74, 1), (28, 72, 4)]
    for first_bar in (16, 24):
        for offset, note, beats in phrase:
            gain = 0.13 if first_bar == 16 else 0.15
            track.add(lead(note + (0 if first_bar == 16 else 12), beats * beat * 0.9), track.at(first_bar, offset), gain, pan=0.05, verb=0.25, echo=0.2)
    track.add(snare(), track.at(31, 1), 0.4, verb=0.2)
    for step in range(8):
        track.add(snare(0.35 + 0.65 * step / 7), track.at(31, 2 + step * 0.25), 0.3, verb=0.2)
    for bar_index in (0, 8, 16, 24):
        track.add(swell(1.6, 9000, 3000, rising=False), track.at(bar_index), 0.08, verb=0.4)
    track.add(swell(beat * 8, 400, 7000), track.at(30), 0.06, verb=0.3)
    finish(track, "music_match_new", -17.0, 0.35, 0.28)
    place("music_match")


if __name__ == "__main__":
    which = sys.argv[1:] or ["menu", "match"]
    if "menu" in which:
        ilha_de_borracha()
    if "match" in which:
        borracha_turbo()
