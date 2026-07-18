#!/usr/bin/env python3
"""Generate the original deterministic 22-second AutoLedger v003 score."""

from __future__ import annotations

import argparse
import json
import math
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]


def midi_frequency(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def smooth_envelope(length: int, sample_rate: int, attack: float, release: float) -> np.ndarray:
    envelope = np.ones(length, dtype=np.float64)
    attack_samples = min(length, max(1, int(attack * sample_rate)))
    release_samples = min(length, max(1, int(release * sample_rate)))
    envelope[:attack_samples] = np.sin(np.linspace(0.0, math.pi / 2.0, attack_samples)) ** 2
    envelope[-release_samples:] *= np.cos(np.linspace(0.0, math.pi / 2.0, release_samples)) ** 2
    return envelope


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def add_voice(
    mix: np.ndarray,
    sample_rate: int,
    start: float,
    duration: float,
    frequency: float,
    amplitude: float,
    pan: float,
    partials: tuple[tuple[float, float], ...],
    attack: float = 0.04,
    release: float = 0.3,
    decay: float = 0.0,
) -> None:
    start_sample = max(0, int(start * sample_rate))
    end_sample = min(len(mix), start_sample + int(duration * sample_rate))
    length = end_sample - start_sample
    if length <= 0:
        return

    t = np.arange(length, dtype=np.float64) / sample_rate
    signal = np.zeros(length, dtype=np.float64)
    for multiplier, weight in partials:
        signal += weight * np.sin(2.0 * math.pi * frequency * multiplier * t)
    if decay > 0.0:
        signal *= np.exp(-decay * t)
    signal *= smooth_envelope(length, sample_rate, attack, release) * amplitude
    left, right = pan_gains(pan)
    mix[start_sample:end_sample, 0] += signal * left
    mix[start_sample:end_sample, 1] += signal * right


def add_soft_tick(mix: np.ndarray, sample_rate: int, start: float, amplitude: float, pan: float) -> None:
    duration = 0.12
    start_sample = max(0, int(start * sample_rate))
    end_sample = min(len(mix), start_sample + int(duration * sample_rate))
    length = end_sample - start_sample
    if length <= 0:
        return
    t = np.arange(length, dtype=np.float64) / sample_rate
    # Fixed inharmonic sines give a gentle percussive onset without using samples or noise.
    signal = (
        np.sin(2.0 * math.pi * 1480.0 * t)
        + 0.55 * np.sin(2.0 * math.pi * 2217.0 * t)
        + 0.25 * np.sin(2.0 * math.pi * 3187.0 * t)
    )
    signal *= np.exp(-38.0 * t) * amplitude
    left, right = pan_gains(pan)
    mix[start_sample:end_sample, 0] += signal * left
    mix[start_sample:end_sample, 1] += signal * right


def render_score(manifest: dict) -> np.ndarray:
    sample_rate = int(manifest["sampleRate"])
    duration = float(manifest["durationSeconds"])
    mix = np.zeros((int(sample_rate * duration), 2), dtype=np.float64)

    pad_partials = ((1.0, 1.0), (2.0, 0.22), (3.0, 0.08), (0.5, 0.12))
    felt_partials = ((1.0, 1.0), (2.0, 0.34), (3.0, 0.13), (4.0, 0.05))
    bell_partials = ((1.0, 1.0), (2.01, 0.32), (3.98, 0.13), (6.02, 0.05))

    for scene_index, scene in enumerate(manifest["scenes"]):
        start = float(scene["start"])
        end = float(scene["end"])
        scene_duration = end - start
        chord = [int(note) for note in scene["chordMidi"]]

        # A low, wide pad changes exactly with each visual chapter.
        for note_index, note in enumerate(chord[:4]):
            add_voice(
                mix,
                sample_rate,
                start,
                scene_duration + 0.34,
                midi_frequency(note),
                0.023 if note_index else 0.029,
                -0.62 + note_index * 0.4,
                pad_partials,
                attack=0.42,
                release=0.65,
            )

        # Four restrained motif notes keep momentum without competing with copy.
        motif_offsets = (0.28, 1.03, 1.78, 2.53)
        motif_order = (2, 4, 1, 3) if scene_index % 2 == 0 else (1, 3, 4, 2)
        for motif_index, offset in enumerate(motif_offsets):
            onset = start + offset
            if onset >= end - 0.12:
                continue
            note = chord[motif_order[motif_index]] + 12
            character = scene["key"]
            partials = bell_partials if character in {"watch", "pro"} else felt_partials
            amplitude = 0.047 if character == "watch" else 0.039
            add_voice(
                mix,
                sample_rate,
                onset,
                min(1.25, end - onset + 0.25),
                midi_frequency(note),
                amplitude,
                -0.28 if motif_index % 2 == 0 else 0.28,
                partials,
                attack=0.012,
                release=0.36,
                decay=2.0 if partials is felt_partials else 1.55,
            )

        # A soft bass pulse grounds the opening and midpoint of every chapter.
        for pulse_offset in (0.08, min(1.68, max(0.72, scene_duration * 0.52))):
            add_voice(
                mix,
                sample_rate,
                start + pulse_offset,
                0.82,
                midi_frequency(chord[0]),
                0.034,
                0.0,
                ((1.0, 1.0), (2.0, 0.12)),
                attack=0.035,
                release=0.42,
                decay=1.8,
            )

        # The transition accent lands on the same timestamp as the blur crossfade.
        if scene_index > 0:
            add_soft_tick(mix, sample_rate, start, 0.032, -0.22 if scene_index % 2 else 0.22)
            add_voice(
                mix,
                sample_rate,
                start,
                1.25,
                midi_frequency(float(scene["accentMidi"])),
                0.045 if scene["key"] == "watch" else 0.035,
                0.34 if scene_index % 2 else -0.34,
                bell_partials,
                attack=0.008,
                release=0.55,
                decay=2.15,
            )

    # A small resolved cadence supports the final lockup without a dramatic sting.
    for offset, note, pan in ((18.05, 76, -0.3), (18.82, 79, 0.25), (19.62, 83, -0.08), (20.43, 88, 0.18)):
        add_voice(
            mix,
            sample_rate,
            offset,
            1.45,
            midi_frequency(note),
            0.032,
            pan,
            bell_partials,
            attack=0.012,
            release=0.58,
            decay=1.5,
        )

    # Short deterministic delays create depth while remaining clean under UI copy.
    dry = mix.copy()
    for delay_seconds, gain, crossfeed in ((0.17, 0.19, True), (0.31, 0.11, False), (0.47, 0.065, True)):
        delay = int(delay_seconds * sample_rate)
        if crossfeed:
            mix[delay:, 0] += dry[:-delay, 1] * gain
            mix[delay:, 1] += dry[:-delay, 0] * gain
        else:
            mix[delay:] += dry[:-delay] * gain

    # Gentle saturation controls peaks; delivery loudness is normalized by FFmpeg.
    mix = np.tanh(mix * 1.35) / 1.35
    peak = float(np.max(np.abs(mix)))
    if peak > 0:
        mix *= 0.82 / peak
    return mix


def write_wav(path: Path, mix: np.ndarray, sample_rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(mix, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        output.writeframes(pcm.tobytes())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=ROOT / "score-manifest.json")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/app_preview_score_v003.wav")
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    mix = render_score(manifest)
    write_wav(args.output, mix, int(manifest["sampleRate"]))
    print(f"Generated original score: {args.output} ({manifest['durationSeconds']}s)")


if __name__ == "__main__":
    main()
