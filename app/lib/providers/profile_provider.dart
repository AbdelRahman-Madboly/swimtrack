// ProfileProvider - manages the UserProfile loaded from shared_preferences.
// null state means no profile has been saved yet (first run / first launch).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../config/constants.dart';

/// Exposes [UserProfile?] - null means first run, profile not yet set up.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, UserProfile?>((ref) {
  final notifier = ProfileNotifier();
  notifier.loadProfile();
  return notifier;
});

/// Manages persisting and loading the swimmer's personal profile.
class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(null);

  /// Reads the saved profile JSON string from shared_preferences.
  /// Sets state to null if no profile exists (triggers first-run flow).
  Future<void> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(kPrefKeyProfile);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = UserProfile.fromJson(map);
        debugPrint('ProfileProvider: loaded profile → ${state!.name}');
      } else {
        state = null;
        debugPrint('ProfileProvider: no profile (first run)');
      }
    } catch (e) {
      debugPrint('ProfileProvider: load error → $e');
      state = null;
    }
  }

  /// Serialises [profile] to JSON and writes it to shared_preferences.
  /// Updates in-memory state immediately.
  /// @param profile The [UserProfile] to save.
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefKeyProfile, profile.toJsonString());
      state = profile;
      debugPrint('ProfileProvider: saved profile → ${profile.name}');
    } catch (e) {
      debugPrint('ProfileProvider: save error → $e');
      rethrow;
    }
  }

  /// Clears the saved profile (used for testing / reset).
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPrefKeyProfile);
    state = null;
  }

  /// True when no profile has been saved - user needs to go through setup.
  bool get isFirstRun => state == null;
}