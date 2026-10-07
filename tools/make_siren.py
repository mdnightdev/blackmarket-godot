"""Synthesizes a seamless police siren loop (US-style wail heard from down the
street), so the game ships a siren without any third-party licence.

Usage: python3 make_siren.py <output.wav>
Convert for the game with: ffmpeg -i siren.wav -c:a libvorbis -q:a 4 siren.ogg
"""

import sys
import wave

import numpy as np

SAMPLE_RATE = 44100
CYCLE_SECONDS = 2.4
CYCLES = 2
LOW_HZ = 620.0
HIGH_HZ = 1350.0
HARMONICS = (1.0, 0.45, 0.22, 0.1)
ECHO_DELAY = 0.11
ECHO_GAIN = 0.35
PEAK = 0.7


def wail_frequency(t: np.ndarray) -> np.ndarray:
    phase = (t % CYCLE_SECONDS) / CYCLE_SECONDS
    sweep = 0.5 - 0.5 * np.cos(2.0 * np.pi * phase)
    return LOW_HZ + (HIGH_HZ - LOW_HZ) * sweep


def low_pass(signal: np.ndarray, strength: float) -> np.ndarray:
    output = np.empty_like(signal)
    previous = 0.0
    for index, sample in enumerate(signal):
        previous += strength * (sample - previous)
        output[index] = previous
    return output


def main() -> None:
    length = int(SAMPLE_RATE * CYCLE_SECONDS * CYCLES)
    t = np.arange(length) / SAMPLE_RATE
    # Integrating frequency gives a continuous phase, so the sweep has no clicks.
    turns = np.cumsum(wail_frequency(t)) / SAMPLE_RATE
    # Ending on a whole number of turns makes the loop point inaudible.
    turns *= round(turns[-1]) / turns[-1]
    phase = 2.0 * np.pi * turns
    tone = sum(gain * np.sin(phase * (order + 1)) for order, gain in enumerate(HARMONICS))
    tone = low_pass(tone, 0.35)

    delay = int(SAMPLE_RATE * ECHO_DELAY)
    # np.roll wraps the echo tail to the start, which keeps the loop seamless.
    tone = tone + ECHO_GAIN * np.roll(tone, delay)
    tone = tone / np.max(np.abs(tone)) * PEAK

    samples = (tone * 32767).astype(np.int16)
    with wave.open(sys.argv[1], "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(samples.tobytes())
    print(f"saved {sys.argv[1]} ({length / SAMPLE_RATE:.1f}s)")


if __name__ == "__main__":
    main()
