# SwimTrack app

Flutter companion app for the SwimTrack wrist unit. Android is the target
platform; the other platform folders are the Flutter defaults and have not been
tested.

Status: prototype. Used with the device on a desk only.

## What it does

| Screen | Function |
|---|---|
| Login | Checks that the device answers at `http://192.168.4.1` (the phone joins the device WiFi in system settings first) |
| Profile setup | Name, age, height, weight, stored with shared_preferences |
| Home | Pool length and stroke selector, start and stop, live strokes, laps, stroke rate, SWOLF estimate, distance per stroke |
| History | Sessions from the local SQLite database |
| Session detail | Per-lap table and SWOLF chart |
| Settings | Pool length, sync from the device, simulator mode |

Simulator mode generates sessions and live data in the app so every screen can
be used without the device. Those numbers are random, not recordings.

## Layout

| Folder | Role |
|---|---|
| `lib/models/` | `Session`, `Lap`, `RestInterval`, `LiveData`, `DeviceStatus`, `UserProfile` with JSON parsing for the firmware format |
| `lib/services/` | `DeviceApiService` (Dio REST client), `DatabaseService` (sqflite), `SyncService`, `WiFiService`, `MockDataService` |
| `lib/providers/` | Riverpod state |
| `lib/screens/`, `lib/widgets/` | UI |
| `test/` | Model, repository, REST client and sync tests |

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # with an Android device attached
```

The connect form can be pre-filled at build time:

```bash
flutter run --dart-define=SWIMTRACK_AP_PASSWORD=your-ap-password
```

Without the define the password field starts empty. The app does not switch
WiFi networks itself.

## Tests

| File | Covers |
|---|---|
| `test/models/*` | Firmware JSON parsing (string or numeric floats, missing fields), derived values, local JSON |
| `test/services/database_service_test.dart` | Insert, read, ordering, replace, delete, v1 to v2 migration, on an in-memory SQLite (`sqflite_common_ffi`) |
| `test/services/device_api_service_test.dart` | Every endpoint and the error mapping, against a fake Dio adapter |
| `test/services/sync_service_test.dart` | New-session download, skip of local sessions, partial failure, unreachable device, simulator mode |
| `test/widget_test.dart` | App starts |

## Known limitations

- Session start times are the sync time minus the duration, because the
  device has no clock.
- The live elapsed time is an estimate (25 s per completed lap plus the
  current lap).
- The battery indicator stays hidden or at 0 until the device has a battery
  divider fitted.
