// MockDataService - generates plausible-looking fake swim data for simulator mode.
// Used by all providers when Settings → Simulator Mode is enabled.
// No network calls are made when this service is active.

import 'dart:math';
import '../models/session.dart';
import '../models/device_status.dart';
import '../models/live_data.dart';

/// Generates synthetic swim data so the full app can be tested without the device.
class MockDataService {
  MockDataService._();

  static final _rng = Random();

  // ─── Sessions ──────────────────────────────────────────────────────────────

  /// Generates [count] plausible swimming sessions spread over the last 30 days.
  ///
  /// Each session has 4–10 laps, plausible SWOLF scores (35–55),
  /// and a mix of 25m and 50m pools.
  ///
  /// @param count Number of sessions to generate. Defaults to 5.
  /// @return List of [Session] objects sorted newest-first.
  static List<Session> generateSessions({int count = 5}) {
    final sessions = <Session>[];
    final now = DateTime.now();

    for (int i = 0; i < count; i++) {
      final daysAgo   = i * 3 + _rng.nextInt(2);       // spread over 30 days
      final hoursAgo  = _rng.nextInt(10) + 6;           // morning/afternoon
      final startTime = now.subtract(Duration(days: daysAgo, hours: hoursAgo));
      final lapCount  = 4 + _rng.nextInt(7);            // 4–10 laps
      final poolLen   = _rng.nextBool() ? 25 : 50;

      final laps      = _generateLaps(lapCount, poolLen);
      final avgSwolf  = laps.fold(0.0, (s, l) => s + l.swolf) / laps.length;
      final avgSpm    = laps.fold(0.0, (s, l) => s + l.strokeRate) / laps.length;
      final avgDps    = laps.fold(0.0, (s, l) => s + l.dps) / laps.length;
      final swimSec   = laps.fold(0.0, (s, l) => s + l.timeSeconds).toInt();
      final restSec   = lapCount > 4 ? (15 + _rng.nextInt(30)) : 0;
      final totalSec  = swimSec + restSec;

      sessions.add(Session(
        id:             '${10000 + i}',
        startTime:      startTime,
        poolLengthM:    poolLen,
        durationSec:    totalSec,
        totalDistanceM: lapCount * poolLen,
        avgSwolf:       double.parse(avgSwolf.toStringAsFixed(1)),
        avgStrokeRate:  double.parse(avgSpm.toStringAsFixed(1)),
        avgDps:         double.parse(avgDps.toStringAsFixed(2)),
        laps:           laps,
        rests:          lapCount > 4 ? _generateRests(restSec, swimSec) : [],
      ));
    }

    // Newest first
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Generates [count] laps with plausible stroke counts and times.
  /// SWOLF range approximately 35–55.
  static List<Lap> _generateLaps(int count, int poolLen) {
    final laps = <Lap>[];
    for (int n = 1; n <= count; n++) {
      final strokes = 12 + _rng.nextInt(9);             // 12–20 strokes
      final timeSec = 20.0 + _rng.nextDouble() * 15.0; // 20–35 seconds
      final swolf   = strokes + timeSec;
      final spm     = strokes / (timeSec / 60.0);
      final dps     = poolLen / strokes;                 // m per stroke
      laps.add(Lap(
        lapNumber:   n,
        strokeCount: strokes,
        timeSeconds: double.parse(timeSec.toStringAsFixed(1)),
        swolf:       double.parse(swolf.toStringAsFixed(1)),
        strokeRate:  double.parse(spm.toStringAsFixed(1)),
        dps:         double.parse(dps.toStringAsFixed(2)),
      ));
    }
    return laps;
  }

  /// Generates a single plausible rest interval.
  static List<RestInterval> _generateRests(int restSec, int swimSec) {
    return [
      RestInterval(
        startMs:     (swimSec * 0.45 * 1000).toInt(),
        durationSec: restSec.toDouble(),
      ),
    ];
  }

  // ─── Device Status ─────────────────────────────────────────────────────────

  /// Returns a fake [DeviceStatus] representing an idle, healthy device.
  /// Battery is randomised between 80–95%.
  static DeviceStatus generateDeviceStatus() {
    return DeviceStatus(
      mode:            'IDLE',
      batteryPct:      80 + _rng.nextInt(16),
      batteryV:        3.70 + _rng.nextDouble() * 0.42,
      sessionActive:   false,
      firmwareVersion: '1.0.0',
    );
  }

  /// Returns a [DeviceStatus] with sessionActive = true (recording).
  static DeviceStatus generateRecordingStatus() {
    return DeviceStatus(
      mode:            'RECORDING',
      batteryPct:      80 + _rng.nextInt(16),
      batteryV:        3.70 + _rng.nextDouble() * 0.42,
      sessionActive:   true,
      firmwareVersion: '1.0.0',
    );
  }

  // ─── Live Data ─────────────────────────────────────────────────────────────

  /// Generates plausible [LiveData] that increments based on elapsed time.
  ///
  /// Simulates swimming at approximately 14 strokes per 25-second lap.
  ///
  /// @param elapsedSec Seconds since the session started.
  /// @return Fake [LiveData] matching what the real device would return.
  static LiveData generateLiveData(int elapsedSec) {
    const lapDuration  = 25;                            // seconds per simulated lap
    final lapCount     = elapsedSec ~/ lapDuration;
    final lapElapsed   = elapsedSec % lapDuration;

    // Simulate ~14 strokes per lap, roughly 1 stroke per 1.8 seconds
    final strokesThisLap = (lapElapsed / 1.8).floor();
    final totalStrokes   = lapCount * 14 + strokesThisLap;

    final currentSwolf   = strokesThisLap + lapElapsed.toDouble();
    final isResting      = lapElapsed < 3 && lapCount > 0;

    return LiveData(
      strokeCount:  totalStrokes,
      lapCount:     lapCount,
      currentSwolf: double.parse(currentSwolf.toStringAsFixed(1)),
      strokeRate:   28.0 + _rng.nextDouble() * 8.0,    // 28–36 spm
      elapsedSec:   elapsedSec,
      isResting:    isResting,
      lapDps:       strokesThisLap > 0
          ? double.parse((25.0 / strokesThisLap).toStringAsFixed(2))
          : 0.0,
    );
  }
}