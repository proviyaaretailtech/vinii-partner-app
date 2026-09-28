"""Writes assets/sounds/new_order.wav: a loud two-tone ring for the new-order alert.

Generated rather than downloaded so the app carries no third-party audio licence.
Re-run with: python3 tool/make_ring_sound.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sounds' / 'new_order.wav'


def tone(freqs, seconds, volume=0.55):
    frames = []
    total = int(RATE * seconds)
    for i in range(total):
        t = i / RATE
        # Short attack and release so the loop never clicks.
        env = min(1.0, i / (RATE * 0.01), (total - i) / (RATE * 0.02))
        sample = sum(math.sin(2 * math.pi * f * t) for f in freqs) / len(freqs)
        frames.append(int(max(-1.0, min(1.0, sample * volume * env)) * 32767))
    return frames


def silence(seconds):
    return [0] * int(RATE * seconds)


pattern = []
for _ in range(2):  # "ring-ring", like a desk phone
    pattern += tone([880, 1320], 0.18) + silence(0.06) + tone([988, 1480], 0.18) + silence(0.12)
pattern += silence(0.5)

OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b''.join(struct.pack('<h', s) for s in pattern))
print(f'wrote {OUT} ({len(pattern) / RATE:.2f} s)')
