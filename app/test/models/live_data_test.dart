import 'package:flutter_test/flutter_test.dart';
import 'package:swimtrack/models/live_data.dart';

void main() {
  group('LiveData.fromJson (GET /api/live)', () {
    final json = <String, dynamic>{
      'strokes': 14,
      'rate_spm': '32.5',
      'stroke_type': 'BACKSTROKE',
      'lap_strokes': 5,
      'laps': 2,
      'resting': false,
      'lap_elapsed_s': '18.4',
      'swolf_est': '23.4',
      'lap_dps': '1.79',
      'session_active': true,
      'session_laps': 3,
      'batt_pct': 0,
      'batt_mv': 0,
    };

    test('parses counts and string-encoded floats', () {
      final d = LiveData.fromJson(json);
      expect(d.strokeCount, 14);
      expect(d.strokeRate, 32.5);
      expect(d.strokeType, 'BACKSTROKE');
      expect(d.lapStrokes, 5);
      expect(d.currentSwolf, 23.4);
      expect(d.lapElapsedS, 18.4);
      expect(d.lapDps, 1.79);
      expect(d.isResting, isFalse);
      expect(d.battPct, 0);
    });

    test('session_laps wins over laps when present', () {
      expect(LiveData.fromJson(json).lapCount, 3);
      final noSession = Map<String, dynamic>.from(json)..remove('session_laps');
      expect(LiveData.fromJson(noSession).lapCount, 2);
    });

    test('elapsed time estimate uses 25 s per completed lap', () {
      final d = LiveData.fromJson(json);
      expect(d.elapsedSec, (3 * 25 + 18.4).toInt());
      expect(d.elapsedFormatted, '01:33');
    });

    test('empty payload gives zeros and the default stroke type', () {
      final d = LiveData.fromJson(const {});
      expect(d.strokeCount, 0);
      expect(d.lapCount, 0);
      expect(d.strokeRate, 0.0);
      expect(d.strokeType, 'FREESTYLE');
      expect(d.elapsedFormatted, '00:00');
    });

    test('numeric strings for integer fields are accepted', () {
      final d = LiveData.fromJson(const {'strokes': '7', 'laps': '1'});
      expect(d.strokeCount, 7);
      expect(d.lapCount, 1);
    });
  });
}
