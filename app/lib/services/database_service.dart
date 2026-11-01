// DatabaseService - SQLite persistence for SwimTrack sessions, laps, and rests.
// Call initDatabase() once on app start before any other method.
//
// v2 migration: adds avg_dps to sessions, dps to laps.
// Existing installs are upgraded via onUpgrade (ALTER TABLE with DEFAULT 0.0).
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session.dart';

/// Singleton service that manages the local SQLite database.
class DatabaseService {
  DatabaseService._(this._factory, this._path);
  static final DatabaseService instance = DatabaseService._(null, null);

  /// Builds a separate service, for example over `sqflite_common_ffi` with
  /// `inMemoryDatabasePath` in tests.
  @visibleForTesting
  factory DatabaseService.withFactory(DatabaseFactory factory,
          {String path = inMemoryDatabasePath}) =>
      DatabaseService._(factory, path);

  final DatabaseFactory? _factory;
  final String? _path;
  Database? _db;

  /// Schema version written by this build.
  static const int schemaVersion = 2;

  // ─── Initialisation ────────────────────────────────────────────────────────

  /// Opens (or creates) the swimtrack.db database and creates tables.
  /// Must be called once before any other method.
  Future<void> initDatabase() async {
    if (_db != null) return;
    final factory = _factory;
    if (factory != null) {
      _db = await factory.openDatabase(
        _path ?? inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version:   schemaVersion,
          onCreate:  _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
      return;
    }

    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, 'swimtrack.db');
    _db = await openDatabase(
      path,
      version:   schemaVersion,
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
    );
    debugPrint('DatabaseService: opened database at $path');
  }

  /// Closes the database. A later [initDatabase] call opens it again.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Creates all tables on first run (fresh install - includes all v2 columns).
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id               TEXT PRIMARY KEY,
        start_time       TEXT NOT NULL,
        pool_length_m    INTEGER NOT NULL,
        duration_sec     INTEGER NOT NULL,
        total_distance_m INTEGER NOT NULL,
        avg_swolf        REAL NOT NULL,
        avg_stroke_rate  REAL NOT NULL,
        avg_dps          REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE laps (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id   TEXT NOT NULL,
        lap_number   INTEGER NOT NULL,
        stroke_count INTEGER NOT NULL,
        time_seconds REAL NOT NULL,
        swolf        REAL NOT NULL,
        stroke_rate  REAL NOT NULL,
        dps          REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE rests (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id   TEXT NOT NULL,
        start_ms     INTEGER NOT NULL,
        duration_sec REAL NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');

    debugPrint('DatabaseService: tables created (v2 schema)');
  }

  /// Upgrades existing database to the latest version.
  /// v1 → v2: add avg_dps column to sessions, dps column to laps.
  /// DEFAULT 0.0 ensures existing rows are not broken.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE sessions ADD COLUMN avg_dps REAL NOT NULL DEFAULT 0.0');
      await db.execute(
          'ALTER TABLE laps ADD COLUMN dps REAL NOT NULL DEFAULT 0.0');
      debugPrint('DatabaseService: migrated v1→v2 - added avg_dps and dps columns');
    }
  }

  Database get _database {
    if (_db == null) throw StateError('DatabaseService not initialised. Call initDatabase() first.');
    return _db!;
  }

  // ─── Write ─────────────────────────────────────────────────────────────────

  /// Inserts or replaces a session (upsert by id).
  /// Also replaces all associated laps and rests.
  /// @param session The [Session] to persist.
  Future<void> insertSession(Session session) async {
    final db = _database;
    await db.transaction((txn) async {
      // Upsert session row
      await txn.insert(
        'sessions',
        {
          'id':               session.id,
          'start_time':       session.startTime.toIso8601String(),
          'pool_length_m':    session.poolLengthM,
          'duration_sec':     session.durationSec,
          'total_distance_m': session.totalDistanceM,
          'avg_swolf':        session.avgSwolf,
          'avg_stroke_rate':  session.avgStrokeRate,
          'avg_dps':          session.avgDps,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Delete existing laps + rests, then reinsert
      await txn.delete('laps',  where: 'session_id = ?', whereArgs: [session.id]);
      await txn.delete('rests', where: 'session_id = ?', whereArgs: [session.id]);

      for (final lap in session.laps) {
        await txn.insert('laps', {
          'session_id':   session.id,
          'lap_number':   lap.lapNumber,
          'stroke_count': lap.strokeCount,
          'time_seconds': lap.timeSeconds,
          'swolf':        lap.swolf,
          'stroke_rate':  lap.strokeRate,
          'dps':          lap.dps,
        });
      }

      for (final rest in session.rests) {
        await txn.insert('rests', {
          'session_id':   session.id,
          'start_ms':     rest.startMs,
          'duration_sec': rest.durationSec,
        });
      }
    });
    debugPrint('DatabaseService: inserted session ${session.id}');
  }

  // ─── Read ──────────────────────────────────────────────────────────────────

  /// Returns all sessions sorted by start_time descending (newest first).
  /// Each session includes its full lap and rest data.
  /// @return List of [Session] objects, may be empty.
  Future<List<Session>> getAllSessions() async {
    final db       = _database;
    final rows     = await db.query('sessions', orderBy: 'start_time DESC');
    final sessions = <Session>[];

    for (final row in rows) {
      final id    = row['id'] as String;
      final laps  = await _getLaps(id);
      final rests = await _getRests(id);
      sessions.add(_rowToSession(row, laps, rests));
    }

    debugPrint('DatabaseService: loaded ${sessions.length} sessions');
    return sessions;
  }

  /// Returns a single session by [id] with full lap and rest data, or null.
  /// @param id Session ID string.
  /// @return [Session] or null if not found.
  Future<Session?> getSession(String id) async {
    final db   = _database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final laps  = await _getLaps(id);
    final rests = await _getRests(id);
    return _rowToSession(rows.first, laps, rests);
  }

  Future<List<Lap>> _getLaps(String sessionId) async {
    final rows = await _database.query(
      'laps',
      where:     'session_id = ?',
      whereArgs: [sessionId],
      orderBy:   'lap_number ASC',
    );
    return rows.map((r) => Lap(
      lapNumber:   r['lap_number']   as int,
      strokeCount: r['stroke_count'] as int,
      timeSeconds: r['time_seconds'] as double,
      swolf:       r['swolf']        as double,
      strokeRate:  r['stroke_rate']  as double,
      dps:         (r['dps'] as double?) ?? 0.0,
    )).toList();
  }

  Future<List<RestInterval>> _getRests(String sessionId) async {
    final rows = await _database.query(
      'rests',
      where:     'session_id = ?',
      whereArgs: [sessionId],
    );
    return rows.map((r) => RestInterval(
      startMs:     r['start_ms']     as int,
      durationSec: r['duration_sec'] as double,
    )).toList();
  }

  Session _rowToSession(
    Map<String, Object?> row,
    List<Lap> laps,
    List<RestInterval> rests,
  ) {
    return Session(
      id:             row['id']               as String,
      startTime:      DateTime.parse(row['start_time'] as String),
      poolLengthM:    row['pool_length_m']    as int,
      durationSec:    row['duration_sec']     as int,
      totalDistanceM: row['total_distance_m'] as int,
      avgSwolf:       row['avg_swolf']        as double,
      avgStrokeRate:  row['avg_stroke_rate']  as double,
      avgDps:         (row['avg_dps'] as double?) ?? 0.0,
      laps:           laps,
      rests:          rests,
    );
  }

  // ─── Delete ────────────────────────────────────────────────────────────────

  /// Deletes a session and all its associated laps and rests.
  /// @param id Session ID string.
  Future<void> deleteSession(String id) async {
    final db = _database;
    await db.transaction((txn) async {
      await txn.delete('rests',    where: 'session_id = ?', whereArgs: [id]);
      await txn.delete('laps',     where: 'session_id = ?', whereArgs: [id]);
      await txn.delete('sessions', where: 'id = ?',         whereArgs: [id]);
    });
    debugPrint('DatabaseService: deleted session $id');
  }
}