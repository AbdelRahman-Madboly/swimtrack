#!/usr/bin/env python3
"""
make_synthetic.py - write a small synthetic SwimTrack session CSV
=================================================================
Generates motion that looks roughly like the dry-land captures (a still
period, freestyle-like and backstroke-like arm cycles, a wall rest and a few
turn spikes) and runs it through the same derived-column code as collect.py.

The output is synthetic. It exists so analyse.py and the tests can run without
real recordings. It says nothing about how the device performs on a swimmer.

Usage:
  python make_synthetic.py out.csv
  python make_synthetic.py out.csv --seed 7 --seconds-per-label 6
"""

import argparse
import csv
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import collect  # noqa: E402  (reuses compute_derived and the CSV header)

SAMPLE_PERIOD_MS = 20          # 50 Hz
STROKE_PERIOD_S = 1.4          # one arm cycle


def _segment(label, n, rng, t0_s):
    """Return a list of raw IMU tuples (ax, ay, az, gx, gy, gz) for one label."""
    rows = []
    for i in range(n):
        t = t0_s + i * SAMPLE_PERIOD_MS / 1000.0
        phase = 2 * math.pi * t / STROKE_PERIOD_S
        noise = rng.normal(0.0, 0.01, 6)
        if label == "freestyle":
            ax = 0.10 + 0.20 * math.sin(phase)           # stays above -0.35 g
            ay = 0.30 * math.cos(phase)
            az = 1.00 + 0.60 * max(0.0, math.sin(phase))
            gx = 250.0 * math.sin(phase)                  # below 482 dps
            gy = 80.0 * math.cos(phase)
            gz = 60.0 * math.sin(phase)
        elif label == "backstroke":
            ax = -0.20 + 0.50 * math.sin(phase)          # dips to about -0.7 g
            ay = 0.20 * math.cos(phase)
            az = 1.00 + 0.50 * max(0.0, -math.sin(phase))
            gx = 300.0 * math.sin(phase)
            gy = 60.0 * math.cos(phase)
            gz = 40.0 * math.sin(phase)
        elif label == "turn_flip":
            spike = 1.0 if (i % 50) < 6 else 0.0          # 120 ms spike each second
            ax, ay, az = 0.0, 0.1, 0.7 + 0.5 * spike
            gx, gy, gz = 20.0, 10.0, 260.0 * spike
        else:  # still, rest_wall
            ax, ay, az = 0.0, 0.0, 1.0
            gx, gy, gz = 0.0, 0.0, 0.0
        rows.append((ax + noise[0], ay + noise[1], az + noise[2],
                     gx + 5 * noise[3], gy + 5 * noise[4], gz + 5 * noise[5]))
    return rows


def generate(path, seed=42, seconds_per_label=8.0,
             labels=("still", "freestyle", "turn_flip", "backstroke", "rest_wall")):
    """Write the synthetic CSV to `path` and return the number of rows."""
    rng = np.random.default_rng(seed)
    state = collect.State()
    n = int(seconds_per_label * 1000 / SAMPLE_PERIOD_MS)
    ts_ms = 1000
    seq = 0
    count = 0

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=collect.CSV_HEADER)
        writer.writeheader()
        for label in labels:
            for ax, ay, az, gx, gy, gz in _segment(label, n, rng, count * 0.02):
                mag_raw = math.sqrt(ax * ax + ay * ay + az * az)
                raw = {
                    "ts_ms": ts_ms, "seq": seq,
                    "ax": round(ax, 4), "ay": round(ay, 4), "az": round(az, 4),
                    "gx": round(gx, 2), "gy": round(gy, 2), "gz": round(gz, 2),
                    "temp_c": 30.0, "mag_raw": round(mag_raw, 4),
                }
                derived = collect.compute_derived(state, raw)
                row = {"pc_time": f"{ts_ms / 1000.0:.3f}", "label": label,
                       "dropped": collect.check_drop(state, seq)}
                row.update(raw)
                row.update(derived)
                writer.writerow(row)
                ts_ms += SAMPLE_PERIOD_MS
                seq = (seq + 1) % 256
                count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description="Write a synthetic SwimTrack CSV")
    parser.add_argument("out", help="output CSV path")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--seconds-per-label", type=float, default=8.0)
    args = parser.parse_args()
    rows = generate(args.out, seed=args.seed,
                    seconds_per_label=args.seconds_per_label)
    print(f"Wrote {rows} synthetic rows to {args.out}")


if __name__ == "__main__":
    main()
