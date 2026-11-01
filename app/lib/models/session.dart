// Session model - matches the ESP32 firmware JSON formats exactly.
//
// GET /api/sessions  (list, from handleGetSessions in wifi_api.cpp):
// [{"id":12010, "duration_s":86.1, "laps":4, "total_strokes":47,
//   "pool_m":25, "total_dist_m":100, "avg_swolf":"9.7"}]
//
// GET /api/sessions/{id}  (full, from _buildJson in session_manager_part3.cpp):
// {"id":12010, "start_ms":1234567890, "end_ms":1234567976,
//  "duration_s":"86.1", "pool_m":25, "laps":4,
//  "total_strokes":47, "total_dist_m":100,
//  "avg_swolf":"9.7", "avg_spm":"38.4",
//  "lap_data":[{"n":1,"t_s":"21.3","strokes":5,"swolf":"26.3","spm":"14.1"},...],
//  "rests":[{"start_ms":45000,"dur_s":"12.3"}]}
//
// Note: numeric fields serialized via serialized(String(...)) arrive as strings.
//
// v2.0 additions (firmware 2.0.0 / DPS support):
//   Lap.dps         - Distance Per Stroke for this lap [m/stroke]  (json key: "dps")
//   Session.avgDps  - Session average DPS [m/stroke]               (json key: "avg_dps")

/// A rest interval between laps.
class RestInterval {
  final int    startMs;
  final double durationSec;

  const RestInterval({required this.startMs, required this.durationSec});

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)  return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// Matches rests array: {"start_ms":45000, "dur_s":"12.3"}
  factory RestInterval.fromJson(Map<String, dynamic> json) => RestInterval(
    startMs:     (json['start_ms'] as num?)?.toInt() ?? 0,
    durationSec: _d(json['dur_s']),
  );

  Map<String, dynamic> toJson() => {'start_ms': startMs, 'dur_s': durationSec};
}

/// One lap within a session.
class Lap {
  final int    lapNumber;
  final int    strokeCount;
  final double timeSeconds;
  final double swolf;
  final double strokeRate;
  final double dps;          // Distance Per Stroke [m/stroke] - firmware v2.0

  const Lap({
    required this.lapNumber,
    required this.strokeCount,
    required this.timeSeconds,
    required this.swolf,
    required this.strokeRate,
    this.dps = 0.0,           // default 0 so old sessions load without crash
  });

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)  return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// Matches lap_data entries: {"n":1,"t_s":"21.3","strokes":5,"swolf":"26.3","spm":"14.1","dps":"1.79"}
  factory Lap.fromJson(Map<String, dynamic> json, {int fallbackN = 1}) => Lap(
    lapNumber:   (json['n'] as num?)?.toInt() ?? fallbackN,
    strokeCount: (json['strokes'] as num?)?.toInt() ?? 0,
    timeSeconds: _d(json['t_s']),
    swolf:       _d(json['swolf']),
    strokeRate:  _d(json['spm']),
    dps:         _d(json['dps']),
  );

  Map<String, dynamic> toJson() => {
    'n': lapNumber, 'strokes': strokeCount,
    't_s': timeSeconds, 'swolf': swolf, 'spm': strokeRate, 'dps': dps,
  };
}

/// A complete swim session.
class Session {
  final String             id;
  final DateTime           startTime;
  final int                poolLengthM;
  final int                durationSec;
  final int                totalDistanceM;
  final double             avgSwolf;
  final double             avgStrokeRate;
  final double             avgDps;         // Session average DPS [m/stroke] - v2.0
  final List<Lap>          laps;
  final List<RestInterval> rests;

  const Session({
    required this.id,
    required this.startTime,
    required this.poolLengthM,
    required this.durationSec,
    required this.totalDistanceM,
    required this.avgSwolf,
    required this.avgStrokeRate,
    required this.laps,
    required this.rests,
    this.avgDps = 0.0,          // default 0 so old sessions load without crash
  });

  int    get lapCount     => laps.isNotEmpty ? laps.length
                             : (poolLengthM > 0 ? totalDistanceM ~/ poolLengthM : 0);
  double get totalRestSec => rests.fold(0.0, (s, r) => s + r.durationSec);

  static double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)  return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  /// Full session from GET /api/sessions/{id}.
  ///
  /// The device has no real-time clock: start_ms is milliseconds since boot,
  /// not a wall-clock time. The start time is therefore approximated as
  /// [now] (default: the moment of sync) minus the session duration.
  factory Session.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final durS      = _d(json['duration_s']).toInt();
    final startTime = (now ?? DateTime.now()).subtract(Duration(seconds: durS));

    final lapList = (json['lap_data'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((e) => Lap.fromJson(e.value as Map<String, dynamic>,
                                 fallbackN: e.key + 1))
        .toList();

    final restList = (json['rests'] as List<dynamic>? ?? [])
        .map((e) => RestInterval.fromJson(e as Map<String, dynamic>))
        .toList();

    return Session(
      id:             json['id'].toString(),
      startTime:      startTime,
      poolLengthM:    (json['pool_m'] as num?)?.toInt()    ?? 25,
      durationSec:    _d(json['duration_s']).toInt(),
      totalDistanceM: (json['total_dist_m'] as num?)?.toInt() ?? 0,
      avgSwolf:       _d(json['avg_swolf']),
      avgStrokeRate:  _d(json['avg_spm']),
      avgDps:         _d(json['avg_dps']),
      laps:           lapList,
      rests:          restList,
    );
  }

  /// Summary from GET /api/sessions list.
  /// Fields: id, duration_s, laps(count), total_strokes, pool_m,
  ///         total_dist_m, avg_swolf
  factory Session.fromSummaryJson(Map<String, dynamic> json, {DateTime? now}) {
    final durS = _d(json['duration_s']).toInt();
    return Session(
      id:             json['id'].toString(),
      startTime:      (now ?? DateTime.now()).subtract(Duration(seconds: durS)),
      poolLengthM:    (json['pool_m'] as num?)?.toInt() ?? 25,
      durationSec:    durS,
      totalDistanceM: (json['total_dist_m'] as num?)?.toInt() ?? 0,
      avgSwolf:       _d(json['avg_swolf']),
      avgStrokeRate:  0.0,
      avgDps:         _d(json['avg_dps']),
      laps:           [],
      rests:          [],
    );
  }

  /// Stored locally in SQLite - uses stable field names.
  Map<String, dynamic> toJson() => {
    'id':               id,
    'start_time':       startTime.toIso8601String(),
    'pool_length_m':    poolLengthM,
    'duration_sec':     durationSec,
    'total_distance_m': totalDistanceM,
    'avg_swolf':        avgSwolf,
    'avg_stroke_rate':  avgStrokeRate,
    'avg_dps':          avgDps,
    'lap_data':         laps.map((l)  => l.toJson()).toList(),
    'rests':            rests.map((r) => r.toJson()).toList(),
  };
}