import 'package:flutter_test/flutter_test.dart';
import 'package:swimtrack/models/session.dart';

import '../helpers/fake_device.dart';

void main() {
  final now = DateTime(2026, 10, 1, 9, 0, 0);

  group('Session.fromJson (GET /api/sessions/{id})', () {
    test('parses string-encoded floats from the firmware', () {
      final s = Session.fromJson(deviceSessionJson(12010), now: now);
      expect(s.id, '12010');
      expect(s.poolLengthM, 25);
      expect(s.durationSec, 66);
      expect(s.totalDistanceM, 50);
      expect(s.avgSwolf, 41.5);
      expect(s.avgStrokeRate, 28.0);
      expect(s.avgDps, closeTo(1.67, 1e-9));
      expect(s.laps, hasLength(2));
      expect(s.laps.first.timeSeconds, 26.5);
      expect(s.laps.first.strokeCount, 15);
      expect(s.rests.single.durationSec, 12.0);
    });

    test('start time is sync time minus duration, not device uptime', () {
      final s = Session.fromJson(deviceSessionJson(1), now: now);
      expect(s.startTime, now.subtract(const Duration(seconds: 66)));
    });

    test('accepts plain numbers as well as strings', () {
      final json = deviceSessionJson(7)
        ..['duration_s'] = 30
        ..['avg_swolf'] = 40;
      final s = Session.fromJson(json, now: now);
      expect(s.durationSec, 30);
      expect(s.avgSwolf, 40.0);
    });

    test('missing optional fields fall back to defaults', () {
      final s = Session.fromJson({'id': 3}, now: now);
      expect(s.poolLengthM, 25);
      expect(s.laps, isEmpty);
      expect(s.rests, isEmpty);
      expect(s.avgDps, 0.0);
      expect(s.avgSwolf, 0.0);
    });

    test('lap numbers fall back to list position', () {
      final json = deviceSessionJson(4)
        ..['lap_data'] = [
          {'t_s': '20.0', 'strokes': 10},
          {'t_s': 'not-a-number', 'strokes': 12},
        ];
      final s = Session.fromJson(json, now: now);
      expect(s.laps.map((l) => l.lapNumber), [1, 2]);
      expect(s.laps[1].timeSeconds, 0.0);
    });
  });

  group('Session.fromSummaryJson (GET /api/sessions)', () {
    test('parses a list entry without lap detail', () {
      final s = Session.fromSummaryJson(deviceSummaryJson(55), now: now);
      expect(s.id, '55');
      expect(s.durationSec, 66);
      expect(s.avgSwolf, 41.5);
      expect(s.laps, isEmpty);
      expect(s.lapCount, 2, reason: 'derived from distance / pool length');
    });
  });

  group('derived values', () {
    test('lapCount prefers the lap list', () {
      final s = Session.fromJson(deviceSessionJson(1, laps: 3), now: now);
      expect(s.lapCount, 3);
    });

    test('lapCount is 0 when pool length is 0', () {
      final s = Session(
        id: 'x', startTime: now, poolLengthM: 0, durationSec: 0,
        totalDistanceM: 100, avgSwolf: 0, avgStrokeRate: 0, laps: [], rests: [],
      );
      expect(s.lapCount, 0);
    });

    test('totalRestSec sums the rest intervals', () {
      final json = deviceSessionJson(1)
        ..['rests'] = [
          {'start_ms': 1, 'dur_s': '10.5'},
          {'start_ms': 2, 'dur_s': 4.5},
        ];
      expect(Session.fromJson(json, now: now).totalRestSec, 15.0);
    });
  });

  group('toJson', () {
    test('writes the stable local field names', () {
      final json = Session.fromJson(deviceSessionJson(9), now: now).toJson();
      expect(json.keys, containsAll([
        'id', 'start_time', 'pool_length_m', 'duration_sec',
        'total_distance_m', 'avg_swolf', 'avg_stroke_rate', 'avg_dps',
        'lap_data', 'rests',
      ]));
      expect((json['lap_data'] as List).first, containsPair('n', 1));
    });

    test('lap and rest JSON round-trip', () {
      const lap = Lap(lapNumber: 2, strokeCount: 14, timeSeconds: 22.5,
          swolf: 36.5, strokeRate: 31.0, dps: 1.79);
      final back = Lap.fromJson(lap.toJson());
      expect(back.lapNumber, 2);
      expect(back.swolf, 36.5);
      expect(back.dps, 1.79);

      const rest = RestInterval(startMs: 4000, durationSec: 8.5);
      final r = RestInterval.fromJson(rest.toJson());
      expect(r.startMs, 4000);
      expect(r.durationSec, 8.5);
    });
  });
}
