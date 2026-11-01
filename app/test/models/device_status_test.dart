import 'package:flutter_test/flutter_test.dart';
import 'package:swimtrack/models/device_status.dart';
import 'package:swimtrack/models/user_profile.dart';

void main() {
  group('DeviceStatus.fromJson (GET /api/status)', () {
    test('parses an idle device', () {
      final s = DeviceStatus.fromJson(const {
        'mode': 'IDLE',
        'session_active': false,
        'wifi_clients': 1,
        'uptime_s': 607,
        'battery_pct': 0,
        'battery_v': 0.0,
        'pool_m': 50,
        'free_heap': 235400,
      });
      expect(s.mode, 'IDLE');
      expect(s.isRecording, isFalse);
      expect(s.poolM, 50);
      expect(s.batteryLabel, '0%');
    });

    test('isRecording follows mode or session_active', () {
      expect(DeviceStatus.fromJson(const {'mode': 'RECORDING'}).isRecording, isTrue);
      expect(DeviceStatus.fromJson(const {'session_active': true}).isRecording, isTrue);
    });

    test('defaults when fields are missing', () {
      final s = DeviceStatus.fromJson(const {});
      expect(s.mode, 'IDLE');
      expect(s.poolM, 25);
      expect(s.batteryPct, 0);
    });
  });

  group('UserProfile', () {
    const p = UserProfile(
        name: 'Sam Lee', age: 30, heightCm: 180, weightKg: 75, gender: 'other');

    test('JSON round-trip', () {
      final back = UserProfile.fromJson(p.toJson());
      expect(back.name, 'Sam Lee');
      expect(back.heightCm, 180);
      expect(p.toJsonString(), contains('"weight_kg":75'));
    });

    test('initials handle one, two and blank names', () {
      expect(p.initials, 'SL');
      expect(p.copyWith(name: 'sam').initials, 'S');
      expect(p.copyWith(name: '  sam   lee  ').initials, 'SL');
      expect(p.copyWith(name: '   ').initials, '?');
      expect(p.copyWith(name: '').initials, '?');
    });

    test('summary line', () {
      expect(p.summaryLine, '30y · 180cm · 75kg');
    });
  });
}
