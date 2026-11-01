// WiFiService - verifies connection to the SwimTrack device.
// 
// The user connects to the SwimTrack WiFi manually in Android Settings.
// This service simply verifies the device is reachable before proceeding.
// No wifi_iot calls needed - the user handles the WiFi switch themselves.

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/constants.dart';

/// Verifies the phone can reach the SwimTrack ESP32 device.
/// The user is expected to connect to the SwimTrack WiFi manually first.
class WiFiService {
  WiFiService._();
  static final WiFiService instance = WiFiService._();

  final _dio = Dio(BaseOptions(
    baseUrl:        kApiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Attempts to reach the device at [kApiBaseUrl].
  /// In simulator mode: always returns true instantly.
  /// In real mode: pings /api/status to confirm the device is reachable.
  ///
  /// @param simulatorMode When true, skips the real network check.
  /// @return true if device is reachable (or simulator), false otherwise.
  Future<bool> connect(String ssid, String password,
      {bool simulatorMode = false}) async {
    if (simulatorMode) {
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('WiFiService: simulator - skipping real check');
      return true;
    }

    debugPrint('WiFiService: pinging device at $kApiBaseUrl…');
    try {
      final resp = await _dio.get('/api/status');
      final reachable = resp.statusCode == 200;
      debugPrint('WiFiService: device reachable = $reachable');
      return reachable;
    } on DioException catch (e) {
      debugPrint('WiFiService: device not reachable → ${e.type}');
      return false;
    } catch (e) {
      debugPrint('WiFiService: ping error → $e');
      return false;
    }
  }

  /// Disconnects - no-op since user manages WiFi manually.
  Future<void> disconnect() async {
    debugPrint('WiFiService: disconnect (user must switch WiFi manually)');
  }

  /// Checks if the device is currently reachable.
  /// @return true if /api/status responds with 200.
  Future<bool> isConnected() async {
    try {
      final resp = await _dio.get('/api/status');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}