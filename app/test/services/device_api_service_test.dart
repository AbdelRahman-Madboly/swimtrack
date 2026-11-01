import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swimtrack/services/device_api_service.dart';

import '../helpers/fake_device.dart';

void main() {
  late FakeDeviceAdapter adapter;
  late DeviceApiService api;

  DeviceApiService build(Map<String, Object?> routes) {
    adapter = FakeDeviceAdapter(routes);
    return DeviceApiService.withDio(fakeDio(adapter));
  }

  test('getStatus parses /api/status', () async {
    api = build({
      'GET /api/status': {'mode': 'RECORDING', 'session_active': true, 'pool_m': 50},
    });
    final s = await api.getStatus();
    expect(s.isRecording, isTrue);
    expect(s.poolM, 50);
  });

  test('getLiveData parses /api/live', () async {
    api = build({
      'GET /api/live': {'strokes': 9, 'rate_spm': '30.0', 'session_laps': 1},
    });
    final d = await api.getLiveData();
    expect(d.strokeCount, 9);
    expect(d.strokeRate, 30.0);
    expect(d.lapCount, 1);
  });

  test('getSessions parses the summary list', () async {
    api = build({
      'GET /api/sessions': [deviceSummaryJson(1), deviceSummaryJson(2)],
    });
    final list = await api.getSessions();
    expect(list.map((s) => s.id), ['1', '2']);
  });

  test('getSession fetches one full session by id', () async {
    api = build({'GET /api/sessions/42': deviceSessionJson(42, laps: 3)});
    final s = await api.getSession('42');
    expect(s.id, '42');
    expect(s.laps, hasLength(3));
  });

  test('startSession posts the pool length and returns the id', () async {
    api = build({'POST /api/session/start': {'ok': true, 'pool_m': 50, 'id': 777}});
    expect(await api.startSession(50), '777');
    expect(adapter.lastBody, {'pool_length_m': 50});
  });

  test('stopSession returns saved_id', () async {
    api = build({'POST /api/session/stop': {'ok': true, 'saved_id': 12010}});
    expect(await api.stopSession(), '12010');
  });

  test('deleteSession calls DELETE on the session path', () async {
    api = build({'DELETE /api/sessions/5': {'ok': true}});
    await api.deleteSession('5');
    expect(adapter.calls, ['DELETE /api/sessions/5']);
  });

  test('connection errors become a DeviceException with guidance', () async {
    api = build({'GET /api/status': DioExceptionType.connectionError});
    await expectLater(
      api.getStatus(),
      throwsA(isA<DeviceException>().having(
          (e) => e.message, 'message', contains('SwimTrack WiFi'))),
    );
  });

  test('timeouts become a DeviceException', () async {
    api = build({'GET /api/live': DioExceptionType.receiveTimeout});
    await expectLater(
      api.getLiveData(),
      throwsA(isA<DeviceException>().having(
          (e) => e.message, 'message', contains('timed out'))),
    );
  });

  test('HTTP errors include the status code', () async {
    api = build({'GET /api/sessions/9': const FakeStatus(404, {'error': 'session not found'})});
    await expectLater(
      api.getSession('9'),
      throwsA(isA<DeviceException>().having(
          (e) => e.message, 'message', contains('404'))),
    );
  });

  test('a malformed body becomes a DeviceException', () async {
    api = build({'GET /api/sessions': {'not': 'a list'}});
    await expectLater(api.getSessions(), throwsA(isA<DeviceException>()));
  });

  test('simulator mode makes no HTTP calls', () async {
    api = build({});
    api.setSimulatorMode(true);
    final sessions = await api.getSessions();
    expect(sessions, hasLength(3));
    await api.deleteSession('1');
    expect(adapter.calls, isEmpty);
  });
}
