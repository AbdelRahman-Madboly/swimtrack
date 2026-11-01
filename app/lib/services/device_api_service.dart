// DeviceApiService - all HTTP calls to the SwimTrack ESP32 device.
// Field names match the actual firmware JSON exactly (verified from source).
// Simulator mode returns mock data - no network calls made.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/device_status.dart';
import '../models/live_data.dart';
import '../models/session.dart';
import '../services/mock_data_service.dart';

/// Thrown when any device API call fails.
class DeviceException implements Exception {
  final String message;
  const DeviceException(this.message);
  @override
  String toString() => 'DeviceException: $message';
}

/// Singleton HTTP client for the SwimTrack ESP32 REST API.
class DeviceApiService {
  DeviceApiService._(this._dio);
  static final DeviceApiService instance = DeviceApiService._(createDio());

  /// Builds a service around a caller-supplied [Dio], e.g. one with a fake
  /// HTTP adapter in tests.
  @visibleForTesting
  factory DeviceApiService.withDio(Dio dio) => DeviceApiService._(dio);

  /// Default client for the device REST API.
  static Dio createDio() => Dio(BaseOptions(
    baseUrl:        kApiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    headers:        {'Accept': 'application/json'},
  ));

  final Dio _dio;

  bool _simulatorMode = false;

  void setSimulatorMode(bool value) {
    _simulatorMode = value;
    debugPrint('DeviceApiService: simulator=$value');
  }

  // ─── GET /api/status ──────────────────────────────────────────────────────
  // Returns: {"mode":"IDLE","session_active":false,"battery_pct":100,
  //           "battery_v":4.2,"pool_m":25,"wifi_clients":1,"uptime_s":60}

  Future<DeviceStatus> getStatus() async {
    if (_simulatorMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockDataService.generateDeviceStatus();
    }
    try {
      final resp = await _dio.get('/api/status');
      return DeviceStatus.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── GET /api/live ────────────────────────────────────────────────────────
  // Returns: {"strokes":14,"rate_spm":"32.5","stroke_type":"FREESTYLE",
  //           "lap_strokes":5,"laps":2,"resting":false,
  //           "lap_elapsed_s":"8.3","swolf_est":"21.8",
  //           "session_active":true,"session_laps":2}

  Future<LiveData> getLiveData({int elapsedSec = 0}) async {
    if (_simulatorMode) return MockDataService.generateLiveData(elapsedSec);
    try {
      final resp = await _dio.get('/api/live');
      return LiveData.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── GET /api/sessions ───────────────────────────────────────────────────
  // Returns: [{"id":12010,"duration_s":86.1,"laps":4,"total_strokes":47,
  //            "pool_m":25,"total_dist_m":100,"avg_swolf":"9.7"}]

  Future<List<Session>> getSessions() async {
    if (_simulatorMode) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MockDataService.generateSessions(count: 3);
    }
    try {
      final resp = await _dio.get('/api/sessions');
      final list = resp.data as List<dynamic>;
      return list
          .map((e) => Session.fromSummaryJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── GET /api/sessions/{id} ───────────────────────────────────────────────
  // Returns full session with lap_data array (see session_manager_part3.cpp)

  Future<Session> getSession(String id) async {
    if (_simulatorMode) {
      await Future.delayed(const Duration(milliseconds: 200));
      return MockDataService.generateSessions(count: 1).first;
    }
    try {
      final resp = await _dio.get('/api/sessions/$id');
      return Session.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── POST /api/session/start ──────────────────────────────────────────────
  // Body:    {"pool_length_m": 25}
  // Returns: {"ok":true,"pool_m":25,"id":1234567}   (id = millis() on device)

  Future<String> startSession(int poolLengthM) async {
    if (_simulatorMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return 'sim_${DateTime.now().millisecondsSinceEpoch}';
    }
    try {
      final resp = await _dio.post(
        '/api/session/start',
        data: {'pool_length_m': poolLengthM},
        options: Options(contentType: 'application/json'),
      );
      // Response: {"ok":true,"pool_m":25,"id":1234567}
      return (resp.data['id'] ?? '0').toString();
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── POST /api/session/stop ───────────────────────────────────────────────
  // Returns: {"ok":true,"saved_id":12010}

  Future<String> stopSession() async {
    if (_simulatorMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return 'sim_done_${DateTime.now().millisecondsSinceEpoch}';
    }
    try {
      final resp = await _dio.post('/api/session/stop');
      // Response: {"ok":true,"saved_id":12010}
      return (resp.data['saved_id'] ?? resp.data['id'] ?? '0').toString();
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── DELETE /api/sessions/{id} ────────────────────────────────────────────
  // Returns: {"ok":true}  or  {"error":"session not found"}

  Future<void> deleteSession(String id) async {
    if (_simulatorMode) return;
    try {
      await _dio.delete('/api/sessions/$id');
    } on DioException catch (e) { throw DeviceException(_msg(e)); }
    catch (e)                   { throw DeviceException('$e'); }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _msg(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Is the device powered on?';
      case DioExceptionType.connectionError:
        return 'Cannot reach device at $kApiBaseUrl.\n'
               'Make sure your phone is connected to the SwimTrack WiFi.';
      case DioExceptionType.badResponse:
        return 'Device error (${e.response?.statusCode}): '
               '${e.response?.data}';
      default:
        return e.message ?? 'Unknown network error.';
    }
  }
}