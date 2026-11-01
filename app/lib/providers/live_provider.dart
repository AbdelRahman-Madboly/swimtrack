// LiveProvider - streams real-time swim data while a session is recording.
// Simulator mode: generates incrementing fake data every 1 second.
// Real mode: polls GET /api/live every 1 second via DeviceApiService.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/device_provider.dart';
import '../providers/settings_provider.dart';
import '../services/mock_data_service.dart';
import '../services/device_api_service.dart';

/// Streams [LiveData?] - null when no session is active.
/// Auto-disposes when no longer watched.
final liveProvider = StreamProvider.autoDispose<LiveData?>((ref) {
  final isRecording  = ref.watch(deviceProvider).isSessionActive;
  final isSimulator  = ref.watch(settingsProvider).simulatorMode;

  if (!isRecording) {
    // Not recording - emit null once and complete
    return Stream.value(null);
  }

  // Recording - emit live data every second
  return _liveStream(isSimulator);
});

/// Returns a stream that emits [LiveData] every second.
Stream<LiveData?> _liveStream(bool isSimulator) async* {
  final stopwatch = Stopwatch()..start();
  final api = DeviceApiService.instance;

  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    final elapsed = stopwatch.elapsed.inSeconds;

    try {
      if (isSimulator) {
        yield MockDataService.generateLiveData(elapsed);
      } else {
        yield await api.getLiveData(elapsedSec: elapsed);
      }
    } catch (e) {
      debugPrint('LiveProvider: poll error → $e');
      yield null;
    }
  }
}