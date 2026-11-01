// DeviceStatus - matches GET /api/status from wifi_server.cpp handleStatus().
//
// Real device JSON (from handleStatus() in wifi_server.cpp):
// {
//   "mode":           "IDLE" | "RECORDING",
//   "session_active": true | false,
//   "wifi_clients":   1,
//   "uptime_s":       607,
//   "battery_pct":    100,
//   "battery_v":      4.2,
//   "pool_m":         25,
//   "free_heap":      235400
// }

/// Current status of the SwimTrack ESP32 device.
class DeviceStatus {
  final String mode;          // "IDLE" or "RECORDING"
  final int    batteryPct;    // 0-100
  final double batteryV;      // e.g. 4.2
  final bool   sessionActive; // true when recording
  final String firmwareVersion;
  final int    poolM;         // current pool length on device

  const DeviceStatus({
    required this.mode,
    required this.batteryPct,
    required this.batteryV,
    required this.sessionActive,
    this.firmwareVersion = '1.0.0',
    this.poolM = 25,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      mode:          (json['mode']           as String?) ?? 'IDLE',
      batteryPct:    (json['battery_pct']    as num?)?.toInt()    ?? 0,
      batteryV:      (json['battery_v']      as num?)?.toDouble() ?? 0.0,
      sessionActive: (json['session_active'] as bool?)            ?? false,
      firmwareVersion: '1.0.0', // not in firmware - hardcoded
      poolM:         (json['pool_m']         as num?)?.toInt()    ?? 25,
    );
  }

  bool   get isRecording => mode == 'RECORDING' || sessionActive;
  String get batteryLabel => '$batteryPct%';

  @override
  String toString() =>
      'DeviceStatus(mode:$mode battery:$batteryPct% pool:${poolM}m)';
}