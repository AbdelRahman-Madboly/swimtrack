#!/usr/bin/env python3
"""
collect.py - SwimTrack data collector
=================================
Reads the ESP32 receiver's Serial CSV stream, adds:
  - pc_time  : wall-clock timestamp (float seconds since epoch)
  - label    : current activity label (keyboard-updated in real time)

Computes derived columns that mirror the firmware algorithms exactly:
  - mag_filt    : EMA(mag_raw, alpha=0.3)
  - gyroZ_abs   : abs(gz)
  - baseline    : slow EMA(mag_raw, alpha=0.02)  - only updated below threshold
  - threshold   : baseline + STROKE_THRESHOLD_G
  - above_thr   : 1 when mag_filt > threshold
  - event_stroke: 1 on ABOVE→BELOW falling edge (one per stroke)
  - event_turn  : 1 when gyroZ_abs > TURN_GYRO_Z_THRESH_DPS for > TURN_SPIKE_MIN_MS
  - variance    : rolling variance of last VARIANCE_WINDOW mag_filt samples
  - dropped     : 1 if seq gap detected (re-checked from stream; receiver also flags)

Keyboard labels (press key to change; label carries forward until changed):
  1 = freestyle      2 = backstroke     3 = breaststroke   4 = butterfly
  5 = turn_flip      6 = turn_open      7 = rest_wall      8 = idle
  0 = still          q = quit

Output: swimtrack_YYYYMMDD_HHMMSS.csv  (flushed every row)

Requirements:
  pip install -r requirements.txt

Usage:
  python collect.py
  python collect.py --port COM3          # Windows
  python collect.py --port /dev/ttyUSB0  # Linux
  python collect.py --port /dev/cu.usbserial-0001  # macOS
"""

import argparse
import csv
import os
import sys
import time
import threading
import collections
import math
import signal
from datetime import datetime

# ── Third-party ────────────────────────────────────────────────────────────────
try:
    import serial
    import serial.tools.list_ports
except ImportError:
    sys.exit("ERROR: pyserial not installed. Run: pip install pyserial")

try:
    import keyboard
    _HAS_KEYBOARD = True
except ImportError:
    _HAS_KEYBOARD = False
    print("WARNING: 'keyboard' module not installed - label switching disabled.")
    print("         Run: pip install keyboard")
    print("         Continuing with label='still'...\n")

# ============================================================
#  CONFIGURATION - edit these to match your hardware
# ============================================================

SERIAL_PORT  = None        # None = auto-detect first ESP32 port
BAUD_RATE    = 115200

# Derived-column parameters - must match firmware config.h
EMA_ALPHA              = 0.3    # mag_filt fast EMA (matches SENDER EMA_ALPHA)
BASELINE_ALPHA         = 0.02   # baseline slow EMA
STROKE_THRESHOLD_G     = 0.095  # g above baseline (STROKE_THRESHOLD_G in config.h)
TURN_GYRO_Z_THRESH_DPS = 150.0  # dps (TURN_GYRO_Z_THRESH_DPS in config.h)
TURN_SPIKE_MIN_MS      = 30     # ms the gyroZ must stay above threshold for a turn event
VARIANCE_WINDOW        = 50     # samples for rolling variance

# Console summary period
CONSOLE_INTERVAL_S = 1.0

# ============================================================
#  CSV COLUMNS  (in output order)
# ============================================================

CSV_HEADER = [
    "pc_time", "label",
    "ts_ms", "seq", "dropped",
    "ax", "ay", "az",
    "gx", "gy", "gz",
    "temp_c", "mag_raw",
    "mag_filt", "gyroZ_abs",
    "baseline", "threshold",
    "above_thr", "event_stroke", "event_turn",
    "variance",
]

# ============================================================
#  LABEL MAP
# ============================================================

LABEL_MAP = {
    "1": "freestyle",
    "2": "backstroke",
    "3": "breaststroke",
    "4": "butterfly",
    "5": "turn_flip",
    "6": "turn_open",
    "7": "rest_wall",
    "8": "idle",
    "0": "still",
}

# ============================================================
#  STATE
# ============================================================

class State:
    def __init__(self):
        self.label          = "still"
        self.running        = True

        # EMA state
        self.mag_filt       = None   # seeded on first sample
        self.baseline       = None   # seeded on first sample

        # above/below threshold tracking (for falling-edge stroke event)
        self.prev_above_thr = 0

        # Turn event state
        self.turn_above_since_ms = None   # device ms when gyroZ crossed up

        # Rolling variance buffer
        self.var_buf        = collections.deque(maxlen=VARIANCE_WINDOW)

        # Drop detection (independent of receiver - double-check)
        self.last_seq       = None
        self.first_packet   = True

        # Console stats
        self.row_count      = 0
        self.window_rows    = 0
        self.last_console   = time.time()

        # Lock for label changes from keyboard thread
        self.lock           = threading.Lock()

    def set_label(self, label: str):
        with self.lock:
            self.label = label

    def get_label(self) -> str:
        with self.lock:
            return self.label


# ============================================================
#  SERIAL PORT AUTO-DETECT
# ============================================================

def find_serial_port() -> str:
    """Return the first port that looks like an ESP32 USB-Serial adapter."""
    candidates = []
    for port in serial.tools.list_ports.comports():
        desc  = (port.description or "").lower()
        manuf = (port.manufacturer or "").lower()
        # CH340, CP210x, FTDI, Silicon Labs
        if any(k in desc + manuf for k in
               ["ch340", "cp210", "ftdi", "silicon", "uart", "usb serial", "esp"]):
            candidates.append(port.device)

    if not candidates:
        # Fallback: first available port
        all_ports = [p.device for p in serial.tools.list_ports.comports()]
        if all_ports:
            return all_ports[0]
        sys.exit("ERROR: No serial ports found. Is the receiver plugged in?")

    return candidates[0]


# ============================================================
#  DERIVED COLUMN COMPUTATION
# ============================================================

def compute_derived(state: State, row: dict) -> dict:
    """
    Compute all derived columns from raw IMU values.
    Mutates `state` in place. Returns dict of derived values.
    """
    mag_raw  = float(row["mag_raw"])
    gz       = float(row["gz"])
    ts_ms    = int(row["ts_ms"])

    # ── EMA mag_filt ──────────────────────────────────────────
    if state.mag_filt is None:
        state.mag_filt = mag_raw
    else:
        state.mag_filt = EMA_ALPHA * mag_raw + (1.0 - EMA_ALPHA) * state.mag_filt
    mag_filt = state.mag_filt

    # ── Baseline (slow EMA - only updated below threshold) ────
    if state.baseline is None:
        state.baseline = mag_filt
    threshold = state.baseline + STROKE_THRESHOLD_G
    if mag_filt <= threshold:
        state.baseline = BASELINE_ALPHA * mag_filt + (1.0 - BASELINE_ALPHA) * state.baseline
    baseline  = state.baseline

    # ── Threshold (recompute after potential baseline update) ─
    threshold = baseline + STROKE_THRESHOLD_G

    # ── above_thr ─────────────────────────────────────────────
    above_thr = 1 if mag_filt > threshold else 0

    # ── event_stroke (falling edge: ABOVE→BELOW) ─────────────
    event_stroke = 1 if (state.prev_above_thr == 1 and above_thr == 0) else 0
    state.prev_above_thr = above_thr

    # ── gyroZ_abs ─────────────────────────────────────────────
    gyroZ_abs = abs(gz)

    # ── event_turn (gyroZ_abs sustained above threshold) ──────
    event_turn = 0
    if gyroZ_abs > TURN_GYRO_Z_THRESH_DPS:
        if state.turn_above_since_ms is None:
            state.turn_above_since_ms = ts_ms
        elif (ts_ms - state.turn_above_since_ms) >= TURN_SPIKE_MIN_MS:
            event_turn = 1   # will remain 1 for every row while above & past min time
    else:
        state.turn_above_since_ms = None

    # ── Rolling variance of mag_filt ──────────────────────────
    state.var_buf.append(mag_filt)
    if len(state.var_buf) < 2:
        variance = 0.0
    else:
        buf  = list(state.var_buf)
        mean = sum(buf) / len(buf)
        variance = sum((x - mean) ** 2 for x in buf) / len(buf)

    return {
        "mag_filt"    : round(mag_filt,  6),
        "gyroZ_abs"   : round(gyroZ_abs, 6),
        "baseline"    : round(baseline,  6),
        "threshold"   : round(threshold, 6),
        "above_thr"   : above_thr,
        "event_stroke": event_stroke,
        "event_turn"  : event_turn,
        "variance"    : round(variance,  8),
    }


# ============================================================
#  DROP DETECTION  (independent of receiver's dropped column)
# ============================================================

def check_drop(state: State, seq: int) -> int:
    """Return 1 if the seq implies a gap since last packet."""
    if state.first_packet:
        state.last_seq    = seq
        state.first_packet = False
        return 0
    expected = (state.last_seq + 1) % 256
    dropped  = 0 if seq == expected else 1
    state.last_seq = seq
    return dropped


# ============================================================
#  KEYBOARD HANDLER
# ============================================================

def start_keyboard_listener(state: State):
    """Start a background thread that watches for label key presses."""
    if not _HAS_KEYBOARD:
        return

    def _listen():
        while state.running:
            try:
                event = keyboard.read_event(suppress=False)
                if event.event_type == keyboard.KEY_DOWN:
                    key = event.name
                    if key == "q":
                        print("\n[QUIT] q pressed - finishing session...")
                        state.running = False
                    elif key in LABEL_MAP:
                        new_label = LABEL_MAP[key]
                        state.set_label(new_label)
                        print(f"\n[LABEL] → {new_label.upper()}")
            except Exception:
                pass

    t = threading.Thread(target=_listen, daemon=True)
    t.start()


# ============================================================
#  CONSOLE SUMMARY
# ============================================================

def print_console(state: State, last_row: dict):
    now  = time.time()
    if now - state.last_console < CONSOLE_INTERVAL_S:
        return
    elapsed = now - state.last_console
    hz = state.window_rows / elapsed if elapsed > 0 else 0.0

    mag   = float(last_row.get("mag_filt", 0))
    gz    = float(last_row.get("gyroZ_abs", 0))
    label = state.get_label()

    sys.stdout.write(
        f"\r[{state.row_count:>6} rows] "
        f"label={label:<14} "
        f"mag_filt={mag:.3f}g  "
        f"|gz|={gz:6.1f}dps  "
        f"{hz:.1f} Hz   "
    )
    sys.stdout.flush()
    state.window_rows = 0
    state.last_console = now


# ============================================================
#  MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="SwimTrack data collector")
    parser.add_argument("--port", default=None,
                        help="Serial port (auto-detected if omitted)")
    args = parser.parse_args()

    # ── Serial port ───────────────────────────────────────────
    port = args.port or SERIAL_PORT or find_serial_port()
    print(f"[INFO] Opening serial port: {port} @ {BAUD_RATE} baud")
    try:
        ser = serial.Serial(port, BAUD_RATE, timeout=2.0)
    except serial.SerialException as e:
        sys.exit(f"ERROR: Cannot open {port}: {e}")

    time.sleep(1.5)   # Let the receiver boot and print its header
    ser.reset_input_buffer()
    print(f"[INFO] Serial open. Listening for CSV stream...\n")

    # ── Output file ────────────────────────────────────────────
    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    csv_filename  = f"swimtrack_{timestamp_str}.csv"
    csv_path      = os.path.join(os.getcwd(), csv_filename)

    print(f"[INFO] Writing to: {csv_path}")
    print(f"[INFO] Label keys: 1=freestyle 2=backstroke 3=breaststroke 4=butterfly")
    print(f"[INFO]             5=turn_flip 6=turn_open 7=rest_wall 8=idle 0=still")
    print(f"[INFO]             q = quit")
    print()

    state = State()
    start_keyboard_listener(state)

    # ── Signal handler (Ctrl+C) ───────────────────────────────
    def _sigint(sig, frame):
        state.running = False
    signal.signal(signal.SIGINT, _sigint)

    csv_file   = open(csv_path, "w", newline="", buffering=1)
    writer     = csv.DictWriter(csv_file, fieldnames=CSV_HEADER)
    writer.writeheader()
    csv_file.flush()

    last_display_row = {}

    try:
        while state.running:
            try:
                raw_line = ser.readline().decode("utf-8", errors="replace").strip()
            except serial.SerialException:
                print("\n[ERROR] Serial disconnected.")
                break

            if not raw_line:
                continue

            # Skip non-CSV lines (boot messages, stats - all start with '[' or letters)
            if not raw_line[0].isdigit():
                # Print receiver [STATS] lines to console for visibility
                if raw_line.startswith("[STATS]") or raw_line.startswith("[WARN]"):
                    print(f"\n{raw_line}")
                continue

            # ── Parse CSV ──────────────────────────────────────
            parts = raw_line.split(",")
            if len(parts) != 11:
                # Malformed line - skip
                continue

            try:
                raw = {
                    "ts_ms"  : parts[0].strip(),
                    "ax"     : parts[1].strip(),
                    "ay"     : parts[2].strip(),
                    "az"     : parts[3].strip(),
                    "gx"     : parts[4].strip(),
                    "gy"     : parts[5].strip(),
                    "gz"     : parts[6].strip(),
                    "temp_c" : parts[7].strip(),
                    "mag_raw": parts[8].strip(),
                    "seq"    : parts[9].strip(),
                    "dropped": parts[10].strip(),
                }
            except (IndexError, ValueError):
                continue

            # ── Drop detection (independent cross-check) ────────
            seq     = int(raw["seq"])
            dropped = check_drop(state, seq)
            # Prefer the receiver's own dropped flag (it may be more accurate
            # if the host is slow), but log both as OR to be safe
            rx_dropped = int(raw["dropped"])
            final_dropped = 1 if (dropped or rx_dropped) else 0

            # ── Derived columns ─────────────────────────────────
            derived = compute_derived(state, raw)

            # ── Build output row ────────────────────────────────
            pc_time = time.time()
            label   = state.get_label()

            out_row = {
                "pc_time"    : f"{pc_time:.6f}",
                "label"      : label,
                "ts_ms"      : raw["ts_ms"],
                "seq"        : raw["seq"],
                "dropped"    : final_dropped,
                "ax"         : raw["ax"],
                "ay"         : raw["ay"],
                "az"         : raw["az"],
                "gx"         : raw["gx"],
                "gy"         : raw["gy"],
                "gz"         : raw["gz"],
                "temp_c"     : raw["temp_c"],
                "mag_raw"    : raw["mag_raw"],
                **derived,
            }

            writer.writerow(out_row)
            csv_file.flush()

            state.row_count  += 1
            state.window_rows += 1
            last_display_row  = out_row

            # ── Console summary ─────────────────────────────────
            print_console(state, last_display_row)

    finally:
        state.running = False
        csv_file.close()
        ser.close()

        total = state.row_count
        drop_count = sum(1 for _ in range(0))  # already tracked live
        print(f"\n\n[DONE] Session saved: {csv_path}")
        print(f"[DONE] Total rows  : {total}")
        print(f"[DONE] Labels used : 1=freestyle 2=backstroke 3=breaststroke 4=butterfly")
        print(f"[DONE]               5=turn_flip 6=turn_open  7=rest_wall  8=idle  0=still")
        print(f"[DONE] Run: python analyse.py {csv_filename}")


if __name__ == "__main__":
    main()
