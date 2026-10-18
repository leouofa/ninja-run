#!/usr/bin/env python3
"""
tools/extract_waveforms.py
Extracts waveform energy envelopes (10Hz RMS, low bass, high transients, beat drops, duration, seed)
from all .mp3 files in tracks/ into data/waveforms.json for procedural level generation in Godot.
"""

import os
import sys
import json
import hashlib
import subprocess
import math
import struct

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRACKS_DIR = os.path.join(PROJECT_DIR, "tracks")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "data")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "waveforms.json")

def get_track_info(filepath):
    """Uses ffprobe to obtain exact duration and sample rate."""
    cmd = [
        "ffprobe",
        "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        filepath
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        duration = float(res.stdout.strip())
    except Exception:
        duration = 0.0
    return duration

def analyze_audio(filepath, duration):
    """
    Decodes audio to mono 8000 Hz 16-bit signed PCM via ffmpeg,
    and downsamples to 10 Hz buckets (800 samples per bucket).
    Calculates RMS, low-frequency bass energy, high transient energy,
    beat peak timestamps, and deterministic 64-bit seed.
    """
    cmd = [
        "ffmpeg",
        "-v", "error",
        "-i", filepath,
        "-f", "s16le",
        "-acodec", "pcm_s16le",
        "-ac", "1",
        "-ar", "8000",
        "-"
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    raw_data, _ = proc.communicate()

    sample_count = len(raw_data) // 2
    if sample_count == 0:
        return None

    # Calculate sha256 seed from raw bytes
    hasher = hashlib.sha256()
    hasher.update(raw_data[:min(len(raw_data), 262144)])  # first 256KB
    seed_int = int(hasher.hexdigest()[:15], 16)

    # 10 Hz buckets: sample_rate = 8000 -> 800 samples per bucket (0.1s)
    bucket_size = 800
    num_buckets = int(math.ceil(sample_count / bucket_size))

    rms_list = []
    low_list = []
    high_list = []

    # Unpack 16-bit signed PCM in chunks
    # Max amplitude is 32768.0
    fmt = f"<{bucket_size}h"
    prev_val = 0

    for b in range(num_buckets):
        start = b * bucket_size * 2
        end = min((b + 1) * bucket_size * 2, len(raw_data))
        chunk_bytes = raw_data[start:end]
        n_samples = len(chunk_bytes) // 2
        if n_samples == 0:
            rms_list.append(0.0)
            low_list.append(0.0)
            high_list.append(0.0)
            continue

        unpacked = struct.unpack(f"<{n_samples}h", chunk_bytes)

        # 1) RMS amplitude
        sum_sq = 0.0
        # 2) High-frequency / transient energy (differences between consecutive samples)
        diff_sq = 0.0
        # 3) Low-frequency / bass energy (simple moving average window)
        low_accum = 0.0

        lp_filter = 0.0
        alpha = 0.08  # approx 100Hz cut at 8kHz

        for s in unpacked:
            norm_s = s / 32768.0
            sum_sq += norm_s * norm_s

            d = norm_s - prev_val
            diff_sq += d * d
            prev_val = norm_s

            lp_filter += alpha * (norm_s - lp_filter)
            low_accum += lp_filter * lp_filter

        rms = math.sqrt(sum_sq / n_samples)
        high = math.sqrt(diff_sq / n_samples) * 1.5
        low = math.sqrt(low_accum / n_samples) * 1.8

        rms_list.append(round(min(1.0, rms * 1.6), 4))
        high_list.append(round(min(1.0, high), 4))
        low_list.append(round(min(1.0, low), 4))

    # Beat detection: find local peaks in (low + high) energy
    beats = []
    combined = [low_list[i] * 0.7 + high_list[i] * 0.3 for i in range(num_buckets)]
    threshold = 0.35
    min_spacing_buckets = 15  # at least 1.5 seconds between detected major beats/turns

    last_beat = -100
    for i in range(2, num_buckets - 2):
        if i - last_beat < min_spacing_buckets:
            continue
        val = combined[i]
        if val > threshold and val > combined[i - 1] and val > combined[i + 1] and val > combined[i - 2] and val > combined[i + 2]:
            timestamp = round(i * 0.1, 2)
            beats.append(timestamp)
            last_beat = i

    avg_rms = sum(rms_list) / max(1, len(rms_list))
    difficulty = min(5, max(1, int(math.ceil(avg_rms * 7.5))))

    return {
        "duration": round(duration, 2),
        "bucket_rate_hz": 10,
        "sample_count_buckets": num_buckets,
        "rms": rms_list,
        "low": low_list,
        "high": high_list,
        "beats": beats,
        "seed": seed_int,
        "difficulty": difficulty
    }

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    all_waveforms = {}

    files = sorted([f for f in os.listdir(TRACKS_DIR) if f.lower().endswith(".mp3")])
    print(f"Found {len(files)} tracks in {TRACKS_DIR}. Processing waveforms...")

    for i, fname in enumerate(files):
        fpath = os.path.join(TRACKS_DIR, fname)
        dur = get_track_info(fpath)
        print(f"[{i+1}/{len(files)}] Processing {fname} ({dur:.1f}s)...")
        data = analyze_audio(fpath, dur)
        if data:
            all_waveforms[fname] = data

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(all_waveforms, f)

    file_size_kb = os.path.getsize(OUTPUT_FILE) / 1024.0
    print(f"Successfully generated {OUTPUT_FILE} ({len(all_waveforms)} tracks, {file_size_kb:.1f} KB)")

if __name__ == "__main__":
    main()
