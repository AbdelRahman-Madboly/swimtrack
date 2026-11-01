// SettingsProvider - manages app settings persisted in shared_preferences.
// Holds pool length preference and simulator mode toggle.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// App-wide settings persisted between sessions.
class AppSettings {
  /// Pool length in metres. Default 25.
  final int poolLengthM;

  /// When true, all device API calls use mock data - no physical device needed.
  final bool simulatorMode;

  const AppSettings({
    this.poolLengthM = kDefaultPoolLength,
    this.simulatorMode = false,
  });

  /// Returns a copy with optionally overridden fields.
  /// Convenience getter - same as poolLengthM.
  int get poolLength => poolLengthM;

  AppSettings copyWith({int? poolLengthM, bool? simulatorMode}) {
    return AppSettings(
      poolLengthM:   poolLengthM   ?? this.poolLengthM,
      simulatorMode: simulatorMode ?? this.simulatorMode,
    );
  }
}

/// Exposes [AppSettings] loaded from shared_preferences on startup.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final notifier = SettingsNotifier();
  notifier.loadSettings();
  return notifier;
});

/// Manages reading and writing app settings to shared_preferences.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  /// Reads persisted settings from shared_preferences.
  /// Falls back to defaults if nothing has been saved yet.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final poolLen = prefs.getInt(kPrefKeyPoolLength) ?? kDefaultPoolLength;
      final simMode = prefs.getBool(kPrefKeySimulatorMode) ?? false;
      state = AppSettings(poolLengthM: poolLen, simulatorMode: simMode);
      debugPrint('SettingsProvider: pool=${poolLen}m, simulator=$simMode');
    } catch (e) {
      debugPrint('SettingsProvider: load error → $e');
    }
  }

  /// Updates pool length and saves to shared_preferences.
  /// @param value Pool length in metres (typically 25 or 50).
  Future<void> setPoolLength(int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kPrefKeyPoolLength, value);
      state = state.copyWith(poolLengthM: value);
      debugPrint('SettingsProvider: pool length → ${value}m');
    } catch (e) {
      debugPrint('SettingsProvider: setPoolLength error → $e');
    }
  }

  /// Enables or disables simulator mode and saves to shared_preferences.
  /// @param value true = use mock data, false = use real device.
  Future<void> setSimulatorMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kPrefKeySimulatorMode, value);
      state = state.copyWith(simulatorMode: value);
      debugPrint('SettingsProvider: simulator mode → $value');
    } catch (e) {
      debugPrint('SettingsProvider: setSimulatorMode error → $e');
    }
  }
}