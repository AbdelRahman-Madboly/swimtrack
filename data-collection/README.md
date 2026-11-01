# SwimTrack data collection

A two-board rig for recording labelled wrist motion, plus the Python tools that
turn a recording into threshold suggestions and a stroke-style classifier for
the firmware.

Status: prototype. One dry-land session has been recorded with it. That
recording is not in this repository.

## How it fits together

```
LOLIN S2 Mini (wrist)        ESP32 dev board (USB)        Laptop
---------------------        ---------------------        ------
MPU-6500 at 50 Hz      --->  receives ESP-NOW      --->   collect.py
boot calibration             prints one CSV line          adds labels and
37-byte packet per           per packet                   derived columns,
sample over ESP-NOW                                       writes a CSV
                                                              |
                                                          analyse.py
                                                          plots, threshold
                                                          suggestions, classifier,
                                                          C++ snippet
```

| Folder | Board or tool |
|---|---|
| `swimtrack-sender/` | Wrist board firmware (LOLIN S2 Mini). Calibrates for 3 s at boot, then sends one `SensorPacket` every 20 ms. |
| `swimtrack-receiver/` | USB board firmware (ESP32 dev module). Prints each packet as a CSV line and flags sequence gaps. |
| `swimtrack-tools/collect.py` | Reads the receiver's serial stream, applies keyboard labels, adds derived columns, writes `swimtrack_YYYYMMDD_HHMMSS.csv`. |
| `swimtrack-tools/analyse.py` | Summary, plots, threshold suggestions, Random Forest classifier, exported decision tree as text and C++. |
| `swimtrack-tools/make_synthetic.py` | Writes a synthetic session CSV so the tools can run without hardware. |

## Build the boards

```bash
cd swimtrack-receiver && pio run -t upload    # note the MAC it prints (optional)
cd ../swimtrack-sender && pio run -t upload   # keep it flat and still for 3 s after boot
```

The sender broadcasts by default, so no pairing is needed. To unicast to one
receiver, copy `swimtrack-sender/src/config_local.example.h` to
`config_local.h` (git-ignored) and set `ESPNOW_PEER_MAC`. Both boards use WiFi
channel 1.

## Record and analyse

```bash
cd swimtrack-tools
pip install -r requirements.txt
python collect.py --port /dev/ttyUSB0
python analyse.py swimtrack_YYYYMMDD_HHMMSS.csv --out-dir results/
```

Label keys while `collect.py` runs (needs the optional `keyboard` package,
which needs root on Linux):

| Key | Label | Key | Label |
|---|---|---|---|
| `1` | freestyle | `6` | turn_open |
| `2` | backstroke | `7` | rest_wall |
| `3` | breaststroke | `8` | idle |
| `4` | butterfly | `0` | still |
| `5` | turn_flip | `q` | quit and save |

`analyse.py` writes `<name>_timeseries.png`, `<name>_boxplots.png`,
`stroke_classifier.txt` and `stroke_classifier.inc`. The cross-validation
figure it prints uses overlapping windows from a single session, so treat it as
a sanity check, not as an accuracy result.

Recorded CSVs and analysis output in `swimtrack-tools/` are git-ignored.

## Try it without hardware

```bash
cd swimtrack-tools
python make_synthetic.py /tmp/synthetic.csv
python analyse.py /tmp/synthetic.csv --out-dir /tmp/swimtrack-out
```

The synthetic data is shaped to separate cleanly. Results on it say nothing
about real swimming.

## Tests

```bash
cd swimtrack-tools
pip install -r requirements-dev.txt
python -m pytest -q
```

The fixture `tests/fixtures/synthetic_session.csv` is produced by
`make_synthetic.py --seconds-per-label 6` and a test checks that it still
regenerates byte for byte.

## CSV columns written by collect.py

| Column | Source | Meaning |
|---|---|---|
| `pc_time` | laptop | Wall-clock time of the row |
| `label` | keyboard | Current activity label |
| `ts_ms`, `seq`, `dropped` | sender, receiver | Device time, packet counter, gap flag |
| `ax`, `ay`, `az` | sender | Acceleration [g], calibration offsets applied |
| `gx`, `gy`, `gz` | sender | Angular rate [dps], calibration offsets applied |
| `temp_c`, `mag_raw` | sender | Die temperature, raw magnitude |
| `mag_filt`, `baseline`, `threshold`, `above_thr`, `event_stroke` | laptop | Mirror of the firmware stroke detector |
| `gyroZ_abs`, `event_turn` | laptop | Mirror of the turn spike check |
| `variance` | laptop | 50-sample variance of `mag_filt` |

## Known limitations

- Only dry-land data has been recorded. No pool session, no turn data.
- The recorded session ran at about 28 Hz because of serial throughput, so a
  50-sample window covered about 1.8 s, while the firmware's window is 1 s.
- The `still` label in that session was unreliable (the board moved during
  boot calibration).
- Only freestyle and backstroke were recorded.
