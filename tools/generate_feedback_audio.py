#!/usr/bin/env python3
"""Original deterministic Rage Cat one-shots. Python standard library only.

Regenerate: python3 tools/generate_feedback_audio.py
Audit without changes: python3 tools/generate_feedback_audio.py --check
No recordings, downloaded samples, external services, or runtime synthesis.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import random
import struct
import wave
import zlib

RATE = 44100
MASTER_CAP_DB = -3.0
HARD_VOICE_CAP = 8
SPECS = {
    "launch": (0.105, 0.42),
    "hit": (0.075, 0.49),
    "critical": (0.155, 0.58),
    "kill": (0.230, 0.50),
    "fire": (0.170, 0.42),
    "lightning": (0.160, 0.40),
    "freeze": (0.200, 0.38),
    "shatter": (0.260, 0.46),
    "shock": (0.200, 0.43),
    "dark": (0.500, 0.32),
    "boss_roar": (0.700, 0.56),
}
TAU = 2.0 * math.pi


def tone(t: float, hz: float, end_hz: float, duration: float) -> float:
    return math.sin(TAU * (hz * t + (end_hz - hz) * t * t / (2.0 * duration)))


def synth(kind: str) -> list[int]:
    duration, peak = SPECS[kind]
    rng = random.Random(0x52414745 + zlib.crc32(kind.encode("ascii")))
    count = round(duration * RATE)
    low_noise = 0.0
    previous_noise = 0.0
    samples = []
    for i in range(count):
        t = i / RATE
        x = t / duration
        noise = rng.uniform(-1.0, 1.0)
        low_noise += 0.13 * (noise - low_noise)
        high_noise = noise - previous_noise
        previous_noise = noise
        if kind == "launch":
            value = (0.75 * tone(t, 700, 250, duration) * math.exp(-x * 10)
                     + low_noise * 1.8 * math.sin(math.pi * x) * math.exp(-x * 2))
        elif kind == "hit":
            value = (tone(t, 220, 85, duration) * math.exp(-x * 7)
                     + 0.32 * noise * math.exp(-x * 19))
        elif kind == "critical":
            value = (0.52 * tone(t, 265, 100, duration) * math.exp(-x * 11)
                     + 0.34 * math.sin(TAU * 1320 * t) * math.exp(-x * 6)
                     + 0.19 * math.sin(TAU * 1980 * t) * math.exp(-x * 8)
                     + 0.14 * high_noise * math.exp(-x * 28))
        elif kind == "kill":
            value = (0.65 * tone(t, 510, 180, duration) * math.exp(-x * 6)
                     + 0.26 * tone(t, 765, 270, duration) * math.exp(-x * 8)
                     + 0.12 * low_noise * math.exp(-x * 12))
        elif kind == "fire":
            value = (2.4 * low_noise * math.exp(-x * 5)
                     + 0.12 * noise * math.exp(-x * 15)
                     + 0.22 * tone(t, 125, 70, duration) * math.exp(-x * 7))
        elif kind == "lightning":
            crackle = (0.5 + 0.5 * math.sin(TAU * 62 * t)) ** 6
            value = (0.43 * high_noise * crackle * math.exp(-x * 7)
                     + 0.22 * tone(t, 1800, 550, duration) * math.exp(-x * 9)
                     + 0.25 * tone(t, 175, 90, duration) * math.exp(-x * 9))
        elif kind == "freeze":
            value = (0.45 * math.sin(TAU * 1175 * t) * math.exp(-x * 5)
                     + 0.26 * math.sin(TAU * 1762.5 * t) * math.exp(-x * 6)
                     + 0.18 * math.sin(TAU * 2350 * t) * math.exp(-x * 9)
                     + 0.1 * high_noise * math.exp(-x * 15))
        elif kind == "shatter":
            value = sum(
                weight * math.sin(TAU * hz * t + phase) * math.exp(-x * decay)
                for hz, weight, phase, decay in (
                    (1080, .24, 0, 7), (1630, .22, .4, 8),
                    (2210, .18, .9, 10), (3070, .12, 1.3, 12),
                    (3940, .09, 1.8, 13)))
            value += .35 * high_noise * math.exp(-x * 17)
        elif kind == "shock":
            value = (0.8 * tone(t, 230, 58, duration) * math.exp(-x * 6)
                     + .34 * low_noise * math.exp(-x * 11)
                     + .15 * math.sin(TAU * 460 * t) * math.exp(-x * 10))
        elif kind == "dark":
            # One bounded hum, not a loop or a persistent field sound.
            value = (0.7 * math.sin(TAU * 82.4 * t)
                     + .25 * math.sin(TAU * 123.6 * t)
                     + .12 * math.sin(TAU * 164.8 * t)) * math.sin(math.pi * x) ** 2
        elif kind == "boss_roar":
            # Original rough voiced growl: falling fundamental, subharmonics,
            # breath noise and slow amplitude flutter. No animal recording.
            growl = tone(t, 155, 65, duration)
            growl += .45 * tone(t, 310, 130, duration)
            growl += .22 * tone(t, 465, 195, duration)
            value = (growl * (.75 + .25 * math.sin(TAU * 24 * t))
                     + low_noise * 1.8) * math.sin(math.pi * x) ** .7
        else:
            raise ValueError(kind)
        attack = min(1.0, t / (.012 if kind == "dark" else .002))
        release = min(1.0, (count - 1 - i) / (RATE * .018))
        samples.append(value * attack * max(0.0, release))
    # Remove DC before a short fade; normalise to a deliberately modest peak.
    mean = sum(samples) / len(samples)
    samples = [
        (v - mean) * min(1.0, i / (RATE * .002), (count - 1 - i) / (RATE * .003))
        for i, v in enumerate(samples)
    ]
    scale = peak * 32767 / max(abs(v) for v in samples)
    return [round(v * scale) for v in samples]


def wav_bytes(samples: list[int]) -> bytes:
    result = io.BytesIO()
    with wave.open(result, "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    return result.getvalue()


def audit(kind: str, data: bytes) -> tuple[dict, list[int]]:
    with wave.open(io.BytesIO(data), "rb") as source:
        assert source.getnchannels() == 1, f"{kind}: expected mono"
        assert source.getsampwidth() == 2, f"{kind}: expected PCM16"
        assert source.getframerate() == RATE, f"{kind}: expected 44100 Hz"
        assert source.getcomptype() == "NONE", f"{kind}: expected uncompressed PCM"
        frames = source.getnframes()
        samples = list(struct.unpack(f"<{frames}h", source.readframes(frames)))
    duration = frames / RATE
    assert abs(duration - SPECS[kind][0]) <= 1 / RATE, f"{kind}: duration mismatch"
    assert .025 <= duration <= .75, f"{kind}: duration unbounded"
    peak = max(abs(v) for v in samples) / 32767
    rms = math.sqrt(sum(v * v for v in samples) / len(samples)) / 32767
    assert 0 < peak <= .60, f"{kind}: silence or peak exceeded"
    assert all(-32768 < v < 32767 for v in samples), f"{kind}: clipped sample"
    assert samples[0] == samples[-1] == 0, f"{kind}: discontinuous endpoints"
    assert abs(sum(samples) / len(samples) / 32767) < .002, f"{kind}: excessive DC"
    return {
        "file": f"{kind}.wav", "sha256": hashlib.sha256(data).hexdigest(),
        "frames": frames, "duration_seconds": round(duration, 8),
        "peak_linear": round(peak, 8), "rms_linear": round(rms, 8),
        "sample_rate_hz": RATE, "channels": 1, "bits_per_sample": 16,
    }, samples


def build_manifest(blobs: dict[str, bytes]) -> dict:
    audited = {kind: audit(kind, data) for kind, data in blobs.items()}
    master_linear = 10 ** (MASTER_CAP_DB / 20)
    # Any N streams with per-voice gain master/N have coherent full-scale
    # bound master. Explicitly check 1..8 identical and mixed aligned assets.
    aligned_peak = 0.0
    for voices in range(1, HARD_VOICE_CAP + 1):
        gain = master_linear / voices
        for _, samples in audited.values():
            aligned_peak = max(aligned_peak, max(abs(v) for v in samples) / 32767 * gain * voices)
        selected = [audited[kind][1] for kind in list(audited)[:voices]]
        for i in range(max(map(len, selected))):
            mix = sum(s[i] if i < len(s) else 0 for s in selected) / 32767 * gain
            aligned_peak = max(aligned_peak, abs(mix))
    assert master_linear < .71 and aligned_peak < .43, "aggregate mix lacks headroom"
    return {
        "generator": "tools/generate_feedback_audio.py",
        "provenance": "Original procedural synthesis; no samples or external dependencies.",
        "assets": {kind: details for kind, (details, _) in audited.items()},
        "mix_headroom": {
            "hard_voice_cap": HARD_VOICE_CAP,
            "hard_master_cap_db": MASTER_CAP_DB,
            "per_voice_gain_formula": "10 ** (master_db / 20) / configured_voice_cap * event_gain_linear",
            "event_gain_linear_max": 1.0,
            "arbitrary_full_scale_aligned_bound": round(master_linear, 8),
            "generated_assets_aligned_peak_bound": round(aligned_peak, 8),
            "note": "Before external Master-bus gain or device processing; default bus gain is 0 dB.",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate committed assets and deterministic regeneration without writes")
    parser.add_argument("--report", type=Path, help="Optional audit JSON path, preferably outside the source tree")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "resources/audio")
    args = parser.parse_args()
    generated = {kind: wav_bytes(synth(kind)) for kind in SPECS}
    manifest = build_manifest(generated)
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    if args.check:
        for kind, data in generated.items():
            actual = (args.output / f"{kind}.wav").read_bytes()
            audit(kind, actual)
            assert actual == data, f"{kind}: differs from deterministic generator"
        print(f"FEEDBACK AUDIO ASSETS: {len(generated)} WAVs pass PCM/duration/DC/endpoints/no-clipping/determinism; aligned peak <= {manifest['mix_headroom']['generated_assets_aligned_peak_bound']:.4f}, arbitrary full-scale sum <= {manifest['mix_headroom']['arbitrary_full_scale_aligned_bound']:.4f}")
    else:
        args.output.mkdir(parents=True, exist_ok=True)
        for kind, data in generated.items():
            (args.output / f"{kind}.wav").write_bytes(data)
        print(f"Generated {len(generated)} original WAV one-shots in {args.output}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_bytes(manifest_bytes)


if __name__ == "__main__":
    main()
