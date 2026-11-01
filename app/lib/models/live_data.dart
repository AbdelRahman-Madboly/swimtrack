// LiveData - matches GET /api/live from wifi_live.cpp handleLive().
//
// Real device JSON (all string-serialized floats come as strings):
// {
//   "ax": "0.012",  "ay": "-0.003", "az": "1.001",   // IMU (ignored by app)
//   "gx": "0.01",   "gy": "0.02",   "gz": "-0.01",
//   "temp_c": "24.5",
//   "strokes":      14,
//   "rate_spm":     "32.5",        // STRING from serialized(String(...))
//   "stroke_type":  "FREESTYLE",
//   "lap_strokes":  5,
//   "laps":         2,             // from lc->lapCount()
//   "resting":      false,
//   "lap_elapsed_s":"8.3",         // STRING
//   "variance":     "0.0012",      // STRING (ignored by app)
//   "swolf_est":    "21.8",        // STRING
//   "lap_dps":      "1.79",        // STRING - new in firmware v2.0
//   "session_active": true,
//   "session_laps": 2,             // from sm->currentLapCount()
//   "batt_pct":     82,            // integer - added in firmware v2.0 battery task
//   "batt_mv":      3980           // integer - raw mV reading
// }

/// Real-time swim metrics from the device during a recording session.
class LiveData {
  final int    strokeCount;   // "strokes"
  final int    lapCount;      // "session_laps"
  final double currentSwolf;  // "swolf_est" (parsed from string)
  final double strokeRate;    // "rate_spm" (parsed from string)
  final int    elapsedSec;    // derived from lap_elapsed_s + laps * avg_lap_s
  final bool   isResting;     // "resting"
  final int    lapStrokes;    // "lap_strokes"
  final String strokeType;    // "stroke_type"
  final double lapElapsedS;   // "lap_elapsed_s" - current lap time
  final double lapDps;        // "lap_dps" - Distance Per Stroke for current lap [m/stroke]
  final int    battPct;       // "batt_pct" - battery percentage (0–100), 0 = unknown

  const LiveData({
    required this.strokeCount,
    required this.lapCount,
    required this.currentSwolf,
    required this.strokeRate,
    required this.elapsedSec,
    required this.isResting,
    this.lapStrokes = 0,
    this.strokeType = 'FREESTYLE',
    this.lapElapsedS = 0.0,
    this.lapDps = 0.0,
    this.battPct = 0,
  });

  /// Parses a value that may be an int, double, or string.
  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)  return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is num)  return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  factory LiveData.fromJson(Map<String, dynamic> json) {
    final lapElapsed = _d(json['lap_elapsed_s']);
    final lapCount   = _i(json['session_laps']) > 0
        ? _i(json['session_laps'])
        : _i(json['laps']);

    // Approximate total elapsed: completed laps * estimated 25s + current lap
    final elapsedSec = (lapCount * 25 + lapElapsed).toInt();

    return LiveData(
      strokeCount:  _i(json['strokes']),
      lapCount:     lapCount,
      currentSwolf: _d(json['swolf_est']),
      strokeRate:   _d(json['rate_spm']),
      elapsedSec:   elapsedSec,
      isResting:    (json['resting'] as bool?) ?? false,
      lapStrokes:   _i(json['lap_strokes']),
      strokeType:   (json['stroke_type'] as String?) ?? 'FREESTYLE',
      lapElapsedS:  lapElapsed,
      lapDps:       _d(json['lap_dps']),
      battPct:      _i(json['batt_pct']),
    );
  }

  String get elapsedFormatted {
    final m = elapsedSec ~/ 60;
    final s = elapsedSec % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  String toString() =>
      'LiveData(strokes:$strokeCount laps:$lapCount swolf:$currentSwolf '
      'spm:$strokeRate resting:$isResting batt:$battPct%)';
}