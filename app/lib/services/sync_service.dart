// SyncService - fetches sessions from the device and saves new ones to SQLite.
// Simulator mode: inserts fresh mock sessions instead of calling the API.

import 'package:flutter/foundation.dart';
import '../services/device_api_service.dart';
import '../services/database_service.dart';
import '../services/mock_data_service.dart';

/// Result returned by [SyncService.sync].
class SyncResult {
  /// Number of new sessions added to the local database.
  final int newSessions;

  /// Any non-fatal errors encountered during sync.
  final List<String> errors;

  const SyncResult({required this.newSessions, required this.errors});
}

/// Orchestrates pulling sessions from the device into the local SQLite database.
class SyncService {
  SyncService({DeviceApiService? api, DatabaseService? db})
      : _api = api ?? DeviceApiService.instance,
        _db  = db  ?? DatabaseService.instance;

  static final SyncService instance = SyncService();

  final DeviceApiService _api;
  final DatabaseService  _db;

  /// Syncs sessions from the device to the local database.
  ///
  /// Simulator mode: generates 3 fresh mock sessions and inserts them.
  /// Real mode:
  ///   1. Fetches session list from /api/sessions
  ///   2. Compares with locally stored IDs
  ///   3. Downloads and saves any missing sessions
  ///
  /// @param simulatorMode When true, uses mock data.
  /// @return [SyncResult] with count of new sessions and any errors.
  Future<SyncResult> sync({bool simulatorMode = false}) async {
    debugPrint('SyncService: starting sync (simulator=$simulatorMode)');
    await _db.initDatabase();

    if (simulatorMode) {
      return _simulatorSync();
    }
    return _realSync();
  }

  Future<SyncResult> _simulatorSync() async {
    try {
      final sessions = MockDataService.generateSessions(count: 3);
      for (final s in sessions) {
        await _db.insertSession(s);
      }
      debugPrint('SyncService: simulator synced ${sessions.length} sessions');
      return SyncResult(newSessions: sessions.length, errors: []);
    } catch (e) {
      debugPrint('SyncService: simulator sync error → $e');
      return SyncResult(newSessions: 0, errors: ['Simulator sync failed: $e']);
    }
  }

  Future<SyncResult> _realSync() async {
    final errors  = <String>[];
    int   newCount = 0;

    try {
      // 1. Get device session list (summaries)
      final deviceSessions = await _api.getSessions();
      debugPrint('SyncService: device has ${deviceSessions.length} sessions');

      // 2. Get local session IDs
      final localSessions = await _db.getAllSessions();
      final localIds      = localSessions.map((s) => s.id).toSet();

      // 3. Download and save any session not already local
      for (final summary in deviceSessions) {
        if (localIds.contains(summary.id)) {
          debugPrint('SyncService: session ${summary.id} already local, skipping');
          continue;
        }
        try {
          final full = await _api.getSession(summary.id);
          await _db.insertSession(full);
          newCount++;
          debugPrint('SyncService: saved session ${summary.id}');
        } catch (e) {
          final msg = 'Failed to fetch session ${summary.id}: $e';
          debugPrint('SyncService: $msg');
          errors.add(msg);
        }
      }

      debugPrint('SyncService: sync complete - $newCount new, ${errors.length} errors');
      return SyncResult(newSessions: newCount, errors: errors);
    } on DeviceException catch (e) {
      debugPrint('SyncService: device error → ${e.message}');
      return SyncResult(newSessions: newCount, errors: [e.message]);
    } catch (e) {
      debugPrint('SyncService: unexpected error → $e');
      return SyncResult(newSessions: newCount, errors: ['Sync failed: $e']);
    }
  }
}