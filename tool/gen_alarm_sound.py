"""Synthesises the default alarm tone (assets/sounds/doom.wav).

Two-tone, four-pulse pattern with a soft attack so it loops cleanly.
Run: python tool/gen_alarm_sound.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds" / "doom.wav"


def tone(freq: float, dur: float, vol: float = 0.85) -> list[float]:
    n = int(RATE * dur)
    attack = int(RATE * 0.006)
    release = int(RATE * 0.02)
    out = []
    for i in range(n):
        t = i / RATE
        # Square-ish wave: fundamental plus odd harmonics, rolled off so it bites without clipping.
        s = (math.sin(2 * math.pi * freq * t)
             + math.sin(2 * math.pi * freq * 3 * t) / 3
             + math.sin(2 * math.pi * freq * 5 * t) / 6)
        env = 1.0
        if i < attack:
            env = i / attack
        elif i > n - release:
            env = (n - i) / release
        out.append(s * env * vol * 0.62)
    return out


def silence(dur: float) -> list[float]:
    return [0.0] * int(RATE * dur)


def main() -> None:
    samples: list[float] = []
    for _ in range(2):
        for f in (1046.5, 1318.5, 1046.5, 1318.5):
            samples += tone(f, 0.09) + silence(0.045)
        samples += silence(0.32)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f"wrote {OUT} ({len(samples) / RATE:.2f}s)")


if __name__ == "__main__":
    main()
