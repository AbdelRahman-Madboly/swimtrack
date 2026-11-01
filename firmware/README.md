# SwimTrack firmware

Firmware for the SwimTrack wrist unit: LOLIN S2 Mini (ESP32-S2) with a GY-6500
(MPU-6500) breakout. Built with PlatformIO and the Arduino framework.

Status: prototype, dry-land tested only. See [../docs/bench-tests.md](../docs/bench-tests.md).

## What it does

- Reads the MPU-6500 at 50 Hz over I2C (SCL GPIO33, SDA GPIO34).
- Counts strokes with a two-state FSM over the filtered acceleration magnitude
  and labels each stroke freestyle or backstroke with a depth-2 decision tree.
- Detects wall turns (gyro Z spike followed by a glide) and records one lap per
  turn with time, strokes, SWOLF, stroke rate and distance per stroke.
- Detects rest from the variance of the magnitude over 1 s.
- Saves each session as JSON on LittleFS.
- Runs a WiFi access point with a REST API and a browser dashboard at
  `http://192.168.4.1/`.

Algorithm details: [../docs/algorithms.md](../docs/algorithms.md).
REST API: [../docs/api.md](../docs/api.md).
Wiring: [../docs/hardware.md](../docs/hardware.md).

## Build, test, flash

```bash
cp include/secrets.example.h include/secrets.h   # set WIFI_AP_PASS (8 to 63 chars)
pio test -e native                # host unit tests, no hardware
pio run -e lolin_s2_mini          # device build
pio run -e lolin_s2_mini -t upload
pio device monitor -b 115200
```

If `include/secrets.h` is missing, the build uses the placeholder from
`secrets.example.h` and prints a warning. Do not flash the placeholder to a
unit that leaves the bench.

## Source map

| File | Role |
|---|---|
| `include/config.h` | Pins, thresholds and constants |
| `include/secrets.example.h` | Template for the git-ignored `secrets.h` |
| `src/mpu6500*.cpp` | I2C driver, burst read, unit conversion |
| `src/imu_filters.cpp` | EMA filter and magnitude helpers |
| `src/stroke_detector*.cpp` | Stroke FSM, stroke rate, stroke-style tree |
| `src/lap_counter*.cpp` | Turn FSM, lap records, rest detection |
| `src/session_manager*.cpp` | Session lifecycle and JSON on LittleFS |
| `src/wifi_server.cpp`, `wifi_api.cpp`, `wifi_live.cpp` | Access point, routes, dashboard |
| `src/main.cpp` | Setup, 50 Hz loop, state machine, button, serial commands |
| `test/` | Unity tests for the native environment; `test/shim` is a minimal `Arduino.h` |

## Serial commands (115200 baud)

| Key | Action |
|---|---|
| `s` | Start recording |
| `x` | Stop and save |
| `l` | List sessions on flash |
| `p` | Print the last saved session |
| `d` | Delete the last saved session |
| `r` | Reset stroke and lap counters |
| `f` | Print LittleFS usage |
| `i` | Print a live stats snapshot |

The BOOT button starts or stops a session on a short press. A press of 3 s or
more stops any running session and resets the counters.

## Known limitations

- No RTC. Session IDs and times are milliseconds since boot.
- The battery reading needs a 100k/100k divider on GPIO1 that is not fitted, so
  it reports 0.
- Thresholds and the stroke-style tree come from one dry-land session captured
  at about 28 Hz, not 50 Hz. They need a pool recording before they mean
  anything for swimming.
- Breaststroke and butterfly are not classified.
- One phone at a time is the expected use.
