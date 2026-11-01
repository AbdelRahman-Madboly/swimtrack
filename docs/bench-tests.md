# Bench test log

These are the manual checks recorded during development. They were run on a
desk with the hardware in hand. They are not reproducible from this repository
and none of them involved water.

## Firmware, on the ESP32 dev board with an MPU-6050

| Module | Check | Recorded result |
|---|---|---|
| IMU driver | WHO_AM_I and sample rate over 5 s | 0x68, 250 samples in 5.00 s (50.00 Hz) |
| Filters | Serial Plotter, raw and filtered magnitude | Filtered trace settled near 0.90 g at rest |
| Stroke detector | Hand-counted arm swings | Count matched within 1 over 10 strokes |
| Lap counter and rest | Wrist rotation and holding still | Lap confirmed; rest started and ended (8.2 s) |
| Session storage | Save, list, print, delete on LittleFS | Session JSON saved (487 bytes) and removed |
| WiFi API | All endpoints from a phone | Responses correct, 1 client, 50 Hz loop kept |
| Dashboard | Phone browser | Live tiles, start and stop, history worked |
| Integration | Self-test, button, state changes | Self-test passed, 50 Hz stable while recording |
| Power manager | Battery ADC and deep sleep | Not tested |

Issues found and fixed on the way: missing source file, ArduinoJson v6 to v7
migration, truncated source files, a duplicate `main` loop file, a missing WiFi
include. An occasional I2C error 263 was traced to a loose jumper wire.

## Firmware and app, on the LOLIN S2 Mini with the MPU-6500

The firmware was flashed to the target board and used with the app on an
Android phone (start, live view, stop, sync). The fixes from that round are in
`firmware/src/main.cpp` and `firmware/src/wifi_api.cpp`: starting a session
over the API now enters the RECORDING state, and the ADC is forced to 12-bit.

## Capture rig, one dry-land session

| Item | Recorded value |
|---|---|
| Duration | 162 s |
| Rows | 4,494 (about 28 Hz effective) |
| Packet loss | 0 % |
| Labels | freestyle 2,025, backstroke 1,223, rest_wall 1,068, still 178 |
| Known problem | `still` rows unreliable, the board moved during calibration |

The current `STROKE_THRESHOLD_G` (0.095 g), `REST_VARIANCE_THRESH`
(0.16421 g^2) and the stroke-style tree were taken from this session. The CSV
itself is not included.

## What has not been tested

- Any swimming, in a pool or open water
- Turns of any kind
- Breaststroke and butterfly
- Battery power, battery life and deep sleep
- Waterproofing
