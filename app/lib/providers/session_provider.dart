// SessionProvider - manages the list of swim sessions from SQLite.
// sync() now calls SyncService and returns a SyncResult.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../providers/settings_provider.dart';

/// State held by [SessionNotifier].
class SessionState {
  final List<Session> sessions;
  final bool          isLoading;
  final String?       error;

  const SessionState({
    this.sessions  = const [],
    this.isLoading = false,
    this.error,
  });

  SessionState copyWith({
    List<Session>? sessions,
    bool?          isLoading,
    String?        error,
  }) {
    return SessionState(
      sessions:  sessions  ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error:     error,
    );
  }
}

/// Exposes [SessionState] and session operations.
final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final notifier = SessionNotifier(ref);
  notifier.loadFromDatabase();
  return notifier;
});

/// Manages loading, saving, deleting, and syncing sessions.
class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref) : super(const SessionState());

  final Ref _ref;
  final _db   = DatabaseService.instance;
  final _sync = SyncService.instance;

  /// Loads all sessions from SQLite and updates state.
  Future<void> loadFromDatabase() async {
    state = state.copyWith(isLoading: true);
    try {
      await _db.initDatabase();
      final sessions = await _db.getAllSessions();
      state = SessionState(sessions: sessions, isLoading: false);
      debugPrint('SessionProvider: loaded ${sessions.length} sessions');
    } catch (e) {
      debugPrint('SessionProvider: load error → $e');
      state = const SessionState(
        isLoading: false,
        error: 'Could not load sessions. Please restart the app.',
      );
    }
  }

  /// Saves [session] to SQLite then reloads the list.
  Future<void> saveSession(Session session) async {
    try {
      await _db.initDatabase();
      await _db.insertSession(session);
      await loadFromDatabase();
    } catch (e) {
      debugPrint('SessionProvider: save error → $e');
      state = state.copyWith(error: 'Could not save session.');
    }
  }

  /// Deletes session [id] from SQLite then reloads.
  Future<void> deleteSession(String id) async {
    try {
      await _db.initDatabase();
      await _db.deleteSession(id);
      await loadFromDatabase();
    } catch (e) {
      debugPrint('SessionProvider: delete error → $e');
      state = state.copyWith(error: 'Could not delete session.');
    }
  }

  /// Syncs sessions from the device (or mock in simulator) and reloads.
  /// Returns a [SyncResult] so callers can show a toast.
  Future<SyncResult> sync() async {
    final isSimulator = _ref.read(settingsProvider).simulatorMode;
    try {
      final result = await _sync.sync(simulatorMode: isSimulator);
      await loadFromDatabase();
      return result;
    } catch (e) {
      debugPrint('SessionProvider: sync error → $e');
      await loadFromDatabase();
      return SyncResult(newSessions: 0, errors: ['$e']);
    }
  }
}