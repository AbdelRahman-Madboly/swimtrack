# Changelog

## v0.1.0 - 2026-11-01

First public prototype. Firmware, capture rig, analysis tools and app in one
repository. Dry-land tested only.

### Firmware
- Stroke-style classifier now reads gyro X, the axis the decision tree was
  fitted on (it previously read gyro Z).
- Access point SSID and password moved to a git-ignored `include/secrets.h`
  with a committed template. The password is no longer printed on boot.
- `lib_deps` and the platform version pinned; vendored `.pio/libdeps` removed.
- Classifier logic exposed as `StrokeDetector::classifyWindow()` for testing.
- `native` PlatformIO environment with Unity tests for the filter, stroke FSM,
  stroke rate, classifier, turn FSM, lap guard and rest detection.

### Data collection
- Sender defaults to the ESP-NOW broadcast address; a receiver MAC can be set
  in a git-ignored `config_local.h`.
- Both boards pin the platform version and drop unused libraries.
- `analyse.py` split into testable functions, accepts captures without
  `seq`/`dropped`, writes output to `--out-dir`, fixes best-tree selection, and
  exports the tree as a C++ snippet.
- `make_synthetic.py` and a synthetic fixture; pytest suite.
- `collect.py` default stroke threshold matches the firmware.

### App
- Device, database and sync services accept injected clients for testing.
- Session start time no longer misreads device uptime as a calendar date.
- Access point password is no longer compiled in; it can be pre-filled with
  `--dart-define=SWIMTRACK_AP_PASSWORD=...`.
- Removed the unused `wifi_iot` dependency and the location and
  network-change permissions it needed.
- Fixed a crash in profile initials for a blank name.
- Tests for models, the SQLite repository (in-memory), the REST client and the
  sync service against a fake device.

### Repository
- Single MIT license, root README with a working/not-built table, docs for
  hardware, API, algorithms and the bench log.
- CI for PlatformIO builds and tests, pytest, and Flutter analyze and test.
