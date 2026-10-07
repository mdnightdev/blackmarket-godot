"""Synthesizes a distant ship horn for the docks, so the game ships one without
any third-party licence.

Usage: python3 make_horn.py <output.wav>
Convert for the game with: ffmpeg -i horn.wav -c:a libvorbis -q:a 4 ship_horn.ogg
"""

import sys
import wave

import numpy as np

SAMPLE_RATE = 44100
SECONDS = 2.6
FUNDAMENTAL_HZ = 92.0
# A second reed slightly sharp gives the beating sound of a real horn.
DETUNE_RATIO = 1.012
HARMONICS = (1.0, 0.7, 0.45, 0.3, 0.18, 0.1)
ATTACK_SECONDS = 0.25
RELEASE_SECONDS = 0.9
ECHO_DELAY = 0.32
ECHO_GAIN = 0.3
PEAK = 0.6


def reed(t: np.ndarray, frequency: float) -> np.ndarray:
    phase = 2.0 * np.pi * frequency * t
    return sum(gain * np.sin(phase * (order + 1)) for order, gain in enumerate(HARMONICS))


def envelope(t: np.ndarray) -> np.ndarray:
    attack = np.clip(t / ATTACK_SECONDS, 0.0, 1.0)
    release = np.clip((SECONDS - t) / RELEASE_SECONDS, 0.0, 1.0)
    return attack * release


def low_pass(signal: np.ndarray, strength: float) -> np.ndarray:
    output = np.empty_like(signal)
    previous = 0.0
    for index, sample in enumerate(signal):
        previous += strength * (sample - previous)
        output[index] = previous
    return output


def main() -> None:
    t = np.arange(int(SAMPLE_RATE * SECONDS)) / SAMPLE_RATE
    tone = reed(t, FUNDAMENTAL_HZ) + 0.8 * reed(t, FUNDAMENTAL_HZ * DETUNE_RATIO)
    tone = low_pass(tone * envelope(t), 0.08)

    delay = int(SAMPLE_RATE * ECHO_DELAY)
    echo = np.zeros_like(tone)
    echo[delay:] = tone[:-delay]
    tone = tone + ECHO_GAIN * echo
    tone = tone / np.max(np.abs(tone)) * PEAK

    samples = (tone * 32767).astype(np.int16)
    with wave.open(sys.argv[1], "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(samples.tobytes())


if __name__ == "__main__":
    main()
