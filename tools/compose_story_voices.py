#!/usr/bin/env python3
"""Vozes robóticas do Modo história: sílabas curtas sintetizadas, uma voz por personagem.

    python3 tools/compose_story_voices.py

Escreve audio/voices/<voz>_<n>.wav (22 kHz, mono): seis sílabas por voz, com contornos de
tom diferentes (sobe, desce, plana, ondula...), que os cartões de conversa tocam enquanto o
texto se escreve, uma a cada duas ou três letras, com um pouco de variação de tom. Cada robô
tem a sua forma de onda, altura, ritmo e efeito: o BIT é um bip amigável, o AGENTE fala por
rádio, a BIGORNA soa a metal, o ECLIPSE é grave e escuro...
"""
import math
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "voices")

# nome: (frequência base, forma, duração em s, efeito)
VOICES = {
    "0": (560, "square", 0.055, "clean"),        # BIT: bip amigável
    "22": (600, "square", 0.055, "chorus"),      # BIT DE ELITE: o mesmo bip, mais cheio
    "agente": (230, "saw", 0.075, "radio"),      # AGENTE: rádio da polícia
    "locutor": (390, "pulse", 0.06, "stadium"),  # LOCUTOR: voz de estádio
    "6": (310, "saw", 0.06, "growl"),            # ROSCA: motor a roncar
    "1": (270, "square", 0.05, "clip"),          # SALVO: seco, militar
    "4": (150, "square", 0.085, "metal"),        # BIGORNA: grave e metálico
    "8": (720, "sine", 0.05, "vibrato"),         # BATIDA: saltitante
    "3": (840, "triangle", 0.06, "soft"),        # BROTO: fofo
    "9": (190, "saw", 0.08, "wobble"),           # GANCHO: rouco de pirata
    "2": (620, "sine", 0.055, "fm"),             # ÓRBITA: computador
    "7": (460, "square", 0.05, "crackle"),       # FAÍSCA: elétrico
    "11": (115, "saw", 0.09, "drive"),           # MAGNUS: pesado
    "10": (340, "triangle", 0.075, "regal"),     # HÉLIO: quente e nobre
    "5": (95, "saw", 0.1, "dark"),               # ECLIPSE: sombrio
    "narrador": (0, "tick", 0.02, "tick"),       # NARRADOR: tecla de máquina de escrever
}
CONTOURS = [(1.0, 1.0), (0.92, 1.12), (1.12, 0.9), (1.0, 1.18), (1.06, 0.96), (0.95, 1.05)]


def wave_of(shape, phase):
    frac = (phase / (2 * math.pi)) % 1.0
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if shape == "pulse":
        return np.where(frac < 0.3, 1.0, -0.45)
    if shape == "triangle":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    return 2.0 * frac - 1.0  # saw


def syllable(base, shape, duration, effect, contour, rng):
    n = int(RATE * duration)
    t = np.arange(n) / RATE
    if effect == "tick":
        out = rng.standard_normal(n) * np.exp(-t * 400) * 0.6
        out += np.sin(2 * math.pi * 1800 * t) * np.exp(-t * 300) * 0.4
        return out
    start, end = contour
    freq = base * (start + (end - start) * (t / duration))
    if effect == "vibrato":
        freq *= 1 + 0.06 * np.sin(2 * math.pi * 28 * t)
    if effect == "wobble":
        freq *= 1 + 0.08 * np.sin(2 * math.pi * 11 * t)
    if effect == "dark":
        freq *= 1 - 0.25 * (t / duration)
    if effect == "fm":
        freq *= 1 + 0.35 * np.sin(2 * math.pi * base * 1.5 * t)
    phase = 2 * math.pi * np.cumsum(freq) / RATE
    out = wave_of(shape, phase)
    if effect in ("chorus", "stadium", "regal"):
        out = out * 0.6 + wave_of(shape, phase * 1.006) * 0.4
        out += 0.25 * np.sin(phase * 2)
    if effect == "growl":
        out *= 0.7 + 0.3 * np.sign(np.sin(2 * math.pi * 55 * t))
    if effect == "metal":
        out = out * 0.6 + 0.4 * np.sin(phase * 2.76) * np.sin(2 * math.pi * 540 * t)
    if effect == "crackle":
        out += (rng.random(n) < 0.04) * rng.standard_normal(n) * 0.8
    if effect in ("drive", "clip"):
        out = np.clip(out * (2.5 if effect == "drive" else 1.6), -1, 1)
    if effect == "dark":
        out = out * 0.7 + 0.3 * np.sin(phase * 0.5)
    # Envelope curto: ataque rápido, cauda suave.
    attack = np.minimum(1.0, t / 0.006)
    release = np.clip((duration - t) / (duration * 0.45), 0, 1)
    out *= attack * release
    # Um filtro passa-baixo simples tira a aspereza dos bips.
    cutoff = {"radio": 2600, "soft": 3000, "dark": 1400, "metal": 5000}.get(effect, 4200)
    alpha = math.exp(-2 * math.pi * cutoff / RATE)
    smooth = np.empty_like(out)
    acc = 0.0
    for i, v in enumerate(out):
        acc = (1 - alpha) * v + alpha * acc
        smooth[i] = acc
    out = smooth
    if effect == "radio":
        # Rádio: banda estreita, um pouco de ruído e corte seco.
        out = out - np.convolve(out, np.ones(24) / 24, mode="same")
        out += rng.standard_normal(n) * 0.04 * release
        out = np.clip(out * 2.0, -0.8, 0.8)
    if effect in ("stadium", "regal", "dark"):
        # Eco curto de sala grande.
        delay = int(RATE * (0.045 if effect == "stadium" else 0.03))
        tail = np.zeros(n + delay * 3)
        tail[:n] += out
        for k, gain in ((1, 0.45), (2, 0.22), (3, 0.1)):
            tail[k * delay:k * delay + n] += out * gain
        out = tail
    return out


def write(path, samples):
    peak = np.max(np.abs(samples)) or 1.0
    data = (samples / peak * 0.8 * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(5)
    for name, (base, shape, duration, effect) in VOICES.items():
        for i, contour in enumerate(CONTOURS):
            path = os.path.join(OUT, f"{name}_{i}.wav")
            write(path, syllable(base, shape, duration * (0.9 + 0.1 * (i % 3)), effect, contour, rng))
        print("VOICE", name)


if __name__ == "__main__":
    main()
