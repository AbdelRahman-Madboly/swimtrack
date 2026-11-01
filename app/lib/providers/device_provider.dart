// DeviceProvider - manages WiFi connection state and device status.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_status.dart';
import '../services/wifi_service.dart';
import '../services/device_api_service.dart';
import '../providers/settings_provider.dart';

/// Connection state of the SwimTrack device.
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Full state held by [DeviceNotifier].
class DeviceState {
  final ConnectionStatus status;
  final DeviceStatus?    deviceStatus;
  final String?          error;

  const DeviceState({
    this.status      = ConnectionStatus.disconnected,
    this.deviceStatus,
    this.error,
  });

  DeviceState copyWith({
    ConnectionStatus? status,
    DeviceStatus?     deviceStatus,
    String?           error,
    bool              clearError = false,
  }) {
    return DeviceState(
      status:       status       ?? this.status,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      error:        clearError ? null : (error ?? this.error),
    );
  }

  bool get isSessionActive => deviceStatus?.isRecording ?? false;
  bool get isConnected     => status == ConnectionStatus.connected;
}

/// Exposes [DeviceState] - connection status and live device info.
final deviceProvider =
    StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier(ref);
});

/// Manages connection to the SwimTrack ESP32 device.
class DeviceNotifier extends StateNotifier<DeviceState> {
  DeviceNotifier(this._ref) : super(const DeviceState());

  final Ref _ref;
  final _wifi = WiFiService.instance;
  final _api  = DeviceApiService.instance;

  /// Attempts to connect: pings /api/status to verify device is reachable.
  Future<void> connect(String ssid, String password) async {
    state = state.copyWith(status: ConnectionStatus.connecting, clearError: true);

    final isSimulator = _ref.read(settingsProvider).simulatorMode;
    _api.setSimulatorMode(isSimulator);

    try {
      final ok = await _wifi.connect(ssid, password,
          simulatorMode: isSimulator);
      if (!ok) {
        state = state.copyWith(
          status: ConnectionStatus.error,
          error:  'Could not reach device.\nMake sure your phone is on the SwimTrack WiFi.',
        );
        return;
      }
      final status = await _api.getStatus();
      state = DeviceState(
        status:       ConnectionStatus.connected,
        deviceStatus: status,
      );
      debugPrint('DeviceProvider: connected - battery ${status.batteryPct}%');
    } catch (e) {
      debugPrint('DeviceProvider: connect error → $e');
      state = DeviceState(
        status: ConnectionStatus.error,
        error:  e.toString().replaceAll('DeviceException: ', ''),
      );
    }
  }

  /// Disconnects and resets state.
  Future<void> disconnect() async {
    final isSimulator = _ref.read(settingsProvider).simulatorMode;
    if (!isSimulator) await _wifi.disconnect();
    state = const DeviceState(status: ConnectionStatus.disconnected);
    debugPrint('DeviceProvider: disconnected');
  }

  /// Refreshes device status from /api/status.
  Future<void> refreshStatus() async {
    if (!state.isConnected) return;
    try {
      final status = await _api.getStatus();
      state = state.copyWith(deviceStatus: status);
    } catch (e) {
      debugPrint('DeviceProvider: refreshStatus error → $e');
    }
  }

  /// Marks a session as started. Works even if connect() was not called
  /// (e.g. user is on SwimTrack WiFi but hasn't tapped Connect in app).
  void markSessionStarted() {
    final current = state.deviceStatus;
    state = DeviceState(
      status: ConnectionStatus.connected,
      deviceStatus: DeviceStatus(
        mode:            'RECORDING',
        batteryPct:      current?.batteryPct      ?? 100,
        batteryV:        current?.batteryV        ?? 4.2,
        sessionActive:   true,
        firmwareVersion: current?.firmwareVersion ?? '1.0.0',
      ),
    );
    debugPrint('DeviceProvider: session marked started');
  }

  /// Marks a session as stopped.
  void markSessionStopped() {
    final current = state.deviceStatus;
    state = DeviceState(
      status: ConnectionStatus.connected,
      deviceStatus: DeviceStatus(
        mode:            'IDLE',
        batteryPct:      current?.batteryPct      ?? 100,
        batteryV:        current?.batteryV        ?? 4.2,
        sessionActive:   false,
        firmwareVersion: current?.firmwareVersion ?? '1.0.0',
      ),
    );
    debugPrint('DeviceProvider: session marked stopped');
  }
}