"""Sound effects of the powers and the ultimates, made from scratch (no samples, no licences).

    python3 tools/compose_power_sfx.py            # rewrites audio/sfx/premium/<name>.wav

The aim is weight, not beeps: low booms, air, crackling energy and metal, band-limited so
nothing whines on a phone speaker. The ultimate's two-second charge is a low hum that swells,
with a heartbeat that speeds up and a breath of air at the top, instead of a rising tone.
Written as the game's other effects are: 32 kHz, 16-bit stereo, peaks at -2.4 dBFS.
"""
import json
import hashlib
import os
import wave

import numpy as np
from scipy import signal

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "sfx", "premium")
rng = np.random.default_rng(7)
PEAK = 10 ** (-2.4 / 20)


# --- building blocks ----------------------------------------------------------------------
def t_of(seconds):
    return np.arange(int(SR * seconds)) / SR


def noise(seconds):
    return rng.standard_normal(int(SR * seconds))


def band(x, low, high, order=2):
    sos = signal.butter(order, [low, min(high, SR / 2 - 100)], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, cutoff, order=2):
    return signal.sosfilt(signal.butter(order, cutoff, "lowpass", fs=SR, output="sos"), x)


def highpass(x, cutoff, order=2):
    return signal.sosfilt(signal.butter(order, cutoff, "highpass", fs=SR, output="sos"), x)


def env(seconds, attack, decay_rate, hold=0.0):
    t = t_of(seconds)
    rise = np.clip(t / max(attack, 1e-4), 0, 1)
    fall = np.exp(-np.maximum(t - attack - hold, 0) * decay_rate)
    return rise * fall


def boom(seconds=0.8, start=110, end=38, decay=5.0):
    """A sub drop: the body of every impact."""
    t = t_of(seconds)
    f = end + (start - end) * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.003, decay)


def whoosh(seconds=0.5, low=300, high=2400, rise=True, decay=None):
    """Air moving: noise through a band that slides, the swell centred in the sound."""
    n = int(SR * seconds)
    out = np.zeros(n)
    x = noise(seconds)
    block = 256
    for i in range(0, n, block):
        k = i / max(n - 1, 1)
        centre = low * (high / low) ** (k if rise else 1 - k)
        out[i:i + block] = band(x[max(0, i - 2048):i + block], centre * 0.6, centre * 1.6)[-min(block, n - i):]
    shape = np.sin(np.pi * np.clip(np.linspace(0, 1, n), 0, 1)) ** 1.5
    if decay:
        shape = env(seconds, 0.01, decay)
    return out * shape


def crackle(seconds=0.4, density=220, low=1200, high=6000, decay=6.0):
    """Electric sparks: sparse clicks, rung through a band."""
    n = int(SR * seconds)
    clicks = (rng.random(n) < density / SR) * rng.choice([-1.0, 1.0], n) * rng.random(n)
    return band(clicks, low, high) * 6.0 * env(seconds, 0.002, decay)


def hum(seconds, freq, rich=0.5, drift=0.0):
    """An electric drone: a fundamental with soft odd partials, a little detuned wobble."""
    t = t_of(seconds)
    f = freq * (1 + drift * t / max(seconds, 1e-3))
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + rich * 0.35 * np.sin(3 * phase + 0.3) + rich * 0.15 * np.sin(5 * phase)
    return tone * (1 + 0.15 * np.sin(2 * np.pi * 6.5 * t))


def clank(freq=900, seconds=0.35):
    """Metal struck: inharmonic partials that ring and fade."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for ratio, level, rate in ((1.0, 1.0, 14), (2.76, 0.5, 20), (5.4, 0.25, 30), (8.9, 0.12, 40)):
        out += level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * rate)
    return out + band(noise(seconds), 2000, 7000) * np.exp(-t * 90) * 0.6


def shimmer(seconds, notes, level=1.0, decay=2.5):
    """A soft glassy chord: detuned sines with a slow beating, kept in the midrange."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for note in notes:
        f = 440 * 2 ** ((note - 69) / 12)
        for detune in (-0.004, 0.004):
            out += np.sin(2 * np.pi * f * (1 + detune) * t + rng.random() * 6)
    return lowpass(out, 3500) * env(seconds, 0.02, decay) * level / (2 * len(notes))


def at(total, sound, start):
    out = np.zeros(int(SR * total))
    i = int(SR * start)
    n = min(len(sound), len(out) - i)
    out[i:i + n] += sound[:n]
    return out


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[:len(p)] += p
    return out


def stereo(x, width=0.25, delay_ms=9):
    """A little width without phase trouble: a short delayed, filtered copy on one side."""
    d = int(SR * delay_ms / 1000)
    side = np.concatenate([np.zeros(d), lowpass(x, 5000)])[:len(x)]
    left = x + width * side
    right = x - width * side * 0.6
    return np.vstack([left, right])


def finish(name, x, width=0.25, tail=0.02):
    x = np.concatenate([x, np.zeros(int(SR * tail))])
    x = highpass(x, 35)
    fade = int(SR * 0.012)
    x[-fade:] *= np.linspace(1, 0, fade)
    s = stereo(x, width)
    s *= PEAK / max(np.abs(s).max(), 1e-9)
    data = (s.T * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}: {len(x) / SR:.2f}s rms {20 * np.log10(np.sqrt((s ** 2).mean())):.1f} dBFS")


# --- the ultimate: charge and release -------------------------------------------------------
def charging():
    """Two seconds: a low hum swelling a fifth, a heartbeat speeding up under it, air rising
    at the end. Quiet at first, never shrill."""
    total = 2.0
    t = t_of(total)
    grow = (t / total) ** 1.6
    drone = hum(total, 55, rich=0.7, drift=0.5) * (0.25 + 0.75 * grow)
    drone += 0.5 * hum(total, 82.5, rich=0.4, drift=0.5) * grow
    drone = lowpass(drone, 900)
    beats = np.zeros_like(t)
    beat_time, gap = 0.0, 0.42
    while beat_time < total - 0.1:
        beats += at(total, boom(0.3, 90, 45, 14) * (0.4 + 0.6 * beat_time / total), beat_time)
        beat_time += gap
        gap = max(0.12, gap * 0.8)
    air = lowpass(whoosh(total, 200, 1800, rise=True), 2200) * grow ** 2 * 0.7
    sparks = crackle(total, 40, 1200, 3500, 0.0) * grow ** 3 * 0.12
    return mix(drone * 0.9, beats * 0.9, air, sparks) * np.clip(t / 0.08, 0, 1)


def unleash():
    return mix(boom(1.0, 140, 34, 3.5) * 1.2, whoosh(0.7, 3000, 300, rise=False) * 0.7,
               at(1.0, crackle(0.5, 400, 900, 5000, 7), 0.02) * 0.4, band(noise(0.25), 400, 3000) * env(0.25, 0.002, 18) * 0.8)


# --- abilities -------------------------------------------------------------------------------
def ability_blast():
    return mix(boom(0.6, 130, 45, 7), band(noise(0.45), 150, 2500) * env(0.45, 0.002, 9) * 0.9, crackle(0.3, 300, 1500, 5000, 12) * 0.3)


def ability_rapid():
    out = np.zeros(int(SR * 0.4))
    for k in range(5):
        out += at(0.4, mix(clank(420 + 30 * k, 0.08) * 0.5, band(noise(0.05), 800, 4000) * env(0.05, 0.001, 70)), k * 0.055)
    return out + hum(0.4, 110, 0.8, 0.8) * env(0.4, 0.02, 6) * 0.35


def ability_air():
    return mix(whoosh(0.45, 400, 3000, rise=False) * 1.1, boom(0.3, 100, 55, 12) * 0.4)


def ability_ghost():
    x = whoosh(0.6, 250, 1500) + shimmer(0.6, [57, 64], 0.8, 4)
    return lowpass(x, 3000)


def ability_laser():
    t = t_of(0.45)
    saw = signal.sawtooth(2 * np.pi * (180 + 60 * np.exp(-t * 20)) * t)
    beam = band(saw, 200, 2200) * env(0.45, 0.004, 6) * 0.6
    return mix(beam, crackle(0.45, 500, 1500, 6000, 8) * 0.35, boom(0.3, 120, 60, 12) * 0.5)


def ability_rebuild():
    out = np.zeros(int(SR * 0.7))
    for k in range(4):
        out += at(0.7, clank(300 + 40 * k, 0.2) * 0.35, 0.05 + k * 0.1)
    return mix(out, whoosh(0.7, 200, 1200) * 0.5, shimmer(0.7, [52, 59], 0.6, 3))


def ability_mirror():
    return mix(shimmer(0.7, [64, 71, 76], 1.0, 3.5), whoosh(0.5, 800, 3000) * 0.5, clank(1400, 0.3) * 0.15)


def ability_walls():
    rumble = lowpass(noise(0.65), 250) * env(0.65, 0.05, 4) * 1.2
    return mix(rumble, boom(0.6, 80, 40, 5) * 0.8, at(0.65, clank(260, 0.35) * 0.5, 0.18))


def ability_stun():
    return mix(crackle(0.5, 700, 1000, 6000, 6) * 0.8, boom(0.5, 120, 40, 7) * 0.8, whoosh(0.4, 2000, 300, rise=False) * 0.4)


def ability_weld():
    sizzle = band(noise(0.65), 2500, 7000) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t_of(0.65))) * env(0.65, 0.02, 3) * 0.5
    return mix(sizzle, hum(0.65, 100, 0.6) * env(0.65, 0.03, 4) * 0.3, crackle(0.65, 150, 1500, 5000, 4) * 0.3)


def ability_thorns():
    t = t_of(0.5)
    scrape = band(noise(0.5), 1800, 5000) * np.exp(-t * 7) * 0.6
    return mix(scrape, clank(700, 0.45) * 0.6, boom(0.3, 110, 60, 12) * 0.3)


def ability_freeze():
    ice = crackle(0.65, 900, 2500, 8000, 4) * 0.5
    return mix(ice, whoosh(0.6, 3000, 500, rise=False) * 0.6, shimmer(0.65, [72, 79], 0.35, 4))


def ability_magnet():
    t = t_of(0.55)
    wob = hum(0.55, 70, 0.9) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * env(0.55, 0.05, 3.5)
    return mix(lowpass(wob, 800) * 0.9, whoosh(0.5, 300, 1200) * 0.4)


def ability_pierce():
    return mix(clank(520, 0.3) * 0.7, band(noise(0.3), 1500, 6000) * env(0.3, 0.001, 25) * 0.7, boom(0.3, 150, 70, 14) * 0.5)


def power():
    return mix(whoosh(0.4, 400, 2500) * 0.9, boom(0.3, 110, 55, 12) * 0.4)


def ready():
    """The key lights up: a soft, low two-note glow, not a ping."""
    return mix(shimmer(0.6, [60, 67], 1.0, 5), at(0.6, shimmer(0.45, [67, 72], 0.8, 6), 0.1))


# --- the ultimates' own sounds --------------------------------------------------------------
def sun_ray():
    t = t_of(0.8)
    roar = band(noise(0.8), 200, 3500) * env(0.8, 0.02, 3) * 0.8
    return mix(roar, hum(0.8, 65, 1.0) * env(0.8, 0.03, 3) * 0.6, boom(0.6, 120, 40, 5) * 0.8)


def meteor():
    return mix(whoosh(0.35, 600, 200, rise=False) * 0.5, at(0.8, mix(boom(0.6, 100, 34, 6) * 1.1, band(noise(0.5), 100, 1500) * env(0.5, 0.002, 8) * 0.7), 0.15))


def thunder():
    crack = band(noise(0.15), 800, 7000) * env(0.15, 0.001, 30)
    rumble = lowpass(noise(1.1), 200) * env(1.1, 0.08, 2.5) * 1.5
    return mix(crack, rumble, crackle(0.4, 800, 1500, 6000, 9) * 0.4)


def singularity():
    t = t_of(1.5)
    drop = hum(1.5, 90, 0.8, -0.6) * env(1.5, 0.1, 1.8)
    return mix(lowpass(drop, 700), whoosh(1.4, 3000, 150, rise=False) * 0.6, at(1.5, boom(0.8, 100, 30, 4), 0.5))


def void_wave():
    return mix(whoosh(0.7, 200, 1500) * 0.8, boom(0.7, 80, 35, 4) * 0.9)


def void_burst():
    return mix(boom(1.2, 150, 30, 3), band(noise(0.9), 80, 2000) * env(0.9, 0.003, 4) * 0.8, crackle(0.6, 300, 900, 4000, 5) * 0.3)


def sentries():
    out = np.zeros(int(SR * 0.5))
    for k, f in enumerate((300, 380)):
        out += at(0.5, mix(clank(f, 0.3) * 0.6, boom(0.25, 120, 60, 14) * 0.5), k * 0.16)
    return out


def sentry():
    return mix(band(noise(0.18), 600, 4000) * env(0.18, 0.001, 30), boom(0.18, 160, 80, 22) * 0.6)


def bloom():
    return mix(shimmer(1.1, [60, 64, 67, 72], 1.0, 2.5), whoosh(1.0, 200, 1200) * 0.3)


def plunder():
    return mix(whoosh(0.35, 300, 2500), at(0.7, whoosh(0.35, 2500, 300, rise=False), 0.3), at(0.7, boom(0.3, 100, 50, 10) * 0.6, 0.35))


def surge():
    t = t_of(0.6)
    rise = hum(0.6, 80, 0.9, 1.0) * np.clip(t / 0.5, 0, 1) * env(0.6, 0.0, 0.0)
    return mix(lowpass(rise, 1500) * 0.7, crackle(0.6, 500, 1200, 6000, 3) * 0.5, at(0.6, boom(0.25, 140, 60, 14) * 0.6, 0.35))


def volley():
    out = np.zeros(int(SR * 0.55))
    for k in range(3):
        out += at(0.55, mix(whoosh(0.2, 500, 2500) * 0.7, boom(0.15, 120, 60, 18) * 0.4), k * 0.12)
    return out


def plating():
    return mix(shimmer(0.7, [69, 76], 0.9, 4), clank(1200, 0.4) * 0.3, boom(0.3, 90, 50, 12) * 0.4)


SOUNDS = {
    "charging": charging, "unleash": unleash, "power": power, "ready": ready,
    "ability_blast": ability_blast, "ability_rapid": ability_rapid, "ability_air": ability_air,
    "ability_ghost": ability_ghost, "ability_laser": ability_laser, "ability_rebuild": ability_rebuild,
    "ability_mirror": ability_mirror, "ability_walls": ability_walls, "ability_stun": ability_stun,
    "ability_weld": ability_weld, "ability_thorns": ability_thorns, "ability_freeze": ability_freeze,
    "ability_magnet": ability_magnet, "ability_pierce": ability_pierce,
    "sun_ray": sun_ray, "meteor": meteor, "thunder": thunder, "singularity": singularity,
    "void_wave": void_wave, "void_burst": void_burst, "sentries": sentries, "sentry": sentry,
    "bloom": bloom, "plunder": plunder, "surge": surge, "volley": volley, "plating": plating,
}


def refresh_audit():
    path = os.path.join(OUT, "audit.json")
    with open(path) as f:
        audit = json.load(f)
    for asset in audit["assets"]:
        file = os.path.join(OUT, asset["name"])
        with wave.open(file) as w:
            x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float) / 32768
            asset["seconds"] = round(w.getnframes() / w.getframerate(), 2)
        asset["peak_dbfs"] = round(20 * np.log10(max(np.abs(x).max(), 1e-9)), 2)
        asset["rms_dbfs"] = round(20 * np.log10(max(np.sqrt((x ** 2).mean()), 1e-9)), 2)
        with open(file, "rb") as f:
            asset["sha256"] = hashlib.sha256(f.read()).hexdigest()
    audit["total_bytes"] = sum(os.path.getsize(os.path.join(OUT, a["name"])) for a in audit["assets"])
    with open(path, "w") as f:
        json.dump(audit, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    for name, make in SOUNDS.items():
        finish(name, make())
    refresh_audit()
