# Detection algorithms

All detection runs on the wrist unit at 50 Hz (one sample every 20 ms). The
constants live in `firmware/include/config.h`; the host tests in
`firmware/test/` exercise each state machine.

## Filtering

`mag = sqrt(ax^2 + ay^2 + az^2)` in g, smoothed with an EMA (alpha 0.3). The
first sample seeds the filter.

## Strokes (`stroke_detector*.cpp`)

| Step | Rule |
|---|---|
| Baseline | Slow EMA (alpha 0.02) of the filtered magnitude, updated only while the FSM is BELOW. Seeded at 1.0 g. |
| Threshold | `baseline + STROKE_THRESHOLD_G` (0.095 g) |
| BELOW to ABOVE | `mag > threshold` and at least `STROKE_MIN_GAP_MS` (500 ms) since the last stroke |
| ABOVE to BELOW | `mag <= threshold`; one stroke is counted here |
| Stroke rate | 60000 / mean of the last 5 inter-stroke intervals, in strokes per minute |

## Stroke style

When a stroke is counted, the last 50 samples are reduced to two features,
`ax_min` (minimum acceleration on X, g) and `gx_max` (maximum angular rate on
X, dps), and run through a depth-2 tree:

```
ax_min <= -0.35                      -> BACKSTROKE
ax_min >  -0.35 and gx_max <= 482.42 -> FREESTYLE
ax_min >  -0.35 and gx_max >  482.42 -> BACKSTROKE
```

Where the numbers come from: `data-collection/swimtrack-tools/analyse.py`
fitted a Random Forest on one dry-land recording (freestyle and backstroke arm
movements, no water) and exported its best tree. That recording is not in this
repository, so the split values cannot be reproduced from it and no accuracy
figure is claimed. Two further gaps:

- The recording ran at about 28 Hz, so its 50-sample windows covered about
  1.8 s. The firmware window is 1 s.
- The capture rig subtracts boot calibration offsets; the device firmware does
  not.

Until the first window fills, the stroke type is `UNKNOWN`. Breaststroke and
butterfly are never produced.

Earlier firmware fed gyro Z into the `gx_max` feature. The tree was fitted on
gyro X, so this release feeds gyro X.

## Laps (`lap_counter*.cpp`)

| State | Leaves when |
|---|---|
| IDLE | `abs(gz) > 150 dps` and at least `LAP_MIN_DURATION_MS` (15 s) since the last lap, or this is the first lap |
| SPIKE | `abs(gz)` falls back below 150 dps. Spikes shorter than 30 ms go back to IDLE |
| GLIDE_WAIT | Filtered magnitude stays below 1.2 g for 100 ms within 2 s: lap confirmed. Otherwise back to IDLE after 2 s |

Each lap stores its duration, strokes, stroke rate, `SWOLF = strokes + seconds`
and `distance per stroke = pool length / strokes`.

The 150 dps turn threshold is a starting guess. No turn data has been recorded.

## Rest

The variance of the filtered magnitude over the last 50 samples (1 s) is
compared with `REST_VARIANCE_THRESH` (0.16421 g^2). Rest starts when the
variance stays below it for `REST_DURATION_MS` (5 s) and ends as soon as it
rises above it.

## Tuning

`analyse.py` prints candidate values for `STROKE_THRESHOLD_G`,
`TURN_GYRO_Z_THRESH_DPS` and `REST_VARIANCE_THRESH` from a labelled recording,
plus a C++ version of the fitted tree. Treat its output as a starting point and
check it against counted strokes and laps.
