# Device REST API

The wrist unit runs a WiFi access point (SSID and password from
`firmware/include/secrets.h`) and serves HTTP on `http://192.168.4.1`, port 80.
All responses are JSON and carry `Access-Control-Allow-Origin: *`.

Some decimal values are written with fixed precision (for example `"32.5"` or
`32.5`); clients should accept either a number or a numeric string. The app's
models do this.

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/` | | HTML dashboard |
| GET | `/api/status` | | Device state |
| GET | `/api/live` | | Live snapshot |
| GET | `/api/sessions` | | Array of session summaries |
| GET | `/api/sessions/{id}` | | Full session |
| POST | `/api/session/start` | `{"pool_length_m": 25}` | `{"ok": true, "pool_m": 25, "id": ...}` |
| POST | `/api/session/stop` | | `{"ok": true, "saved_id": ...}` |
| POST | `/api/config` | `{"pool_length_m": 50}` | Updated config |
| DELETE | `/api/sessions/{id}` | | `{"ok": true}` |
| OPTIONS | any | | CORS preflight |

## GET /api/status

| Field | Type | Meaning |
|---|---|---|
| `mode` | string | `IDLE` or `RECORDING` |
| `session_active` | bool | Recording in progress |
| `wifi_clients` | int | Stations on the access point |
| `uptime_s` | int | Seconds since boot |
| `pool_m` | int | Current pool length |
| `free_heap` | int | Free heap in bytes |
| `battery_pct`, `battery_v` | number | ADC reading; 0 while no divider is fitted |

## GET /api/live

| Field | Meaning |
|---|---|
| `ax` `ay` `az` `gx` `gy` `gz` `temp_c` | Last IMU sample |
| `strokes` | Strokes since the session started |
| `rate_spm` | Mean stroke rate over the last 5 intervals |
| `stroke_type` | `FREESTYLE`, `BACKSTROKE` or `UNKNOWN` |
| `lap_strokes` | Strokes in the current lap |
| `laps` | Laps counted by the turn detector |
| `session_laps` | Laps stored in the current session |
| `resting` | Rest detector state |
| `lap_elapsed_s` | Time in the current lap |
| `variance` | Current 1 s magnitude variance |
| `swolf_est` | `lap_strokes + lap_elapsed_s` |
| `lap_dps` | Distance per stroke of the last lap |
| `session_active` | Recording in progress |
| `batt_mv`, `batt_pct` | ADC reading; 0 while no divider is fitted |

## Session JSON (GET /api/sessions/{id})

```json
{
  "id": 12010, "start_ms": 120000, "end_ms": 186100,
  "duration_s": 66.1, "pool_m": 25, "laps": 2,
  "total_strokes": 30, "total_dist_m": 50,
  "avg_swolf": 41.5, "avg_spm": 28.0, "avg_dps": 1.67,
  "lap_data": [
    {"n": 1, "t_s": 26.5, "strokes": 15, "swolf": 41.5, "spm": 28.0, "dps": 1.67}
  ],
  "rests": [{"start_ms": 150000, "dur_s": 12.0}]
}
```

`id`, `start_ms` and `end_ms` are milliseconds since boot. The device has no
real-time clock. The summary list (`GET /api/sessions`) has `id`,
`duration_s`, `laps`, `total_strokes`, `pool_m`, `total_dist_m`, `avg_swolf`,
`avg_spm` and `avg_dps`.

The values above are an example of the shape, not a recording.
