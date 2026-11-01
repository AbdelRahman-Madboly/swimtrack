import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swimtrack/models/session.dart';
import 'package:swimtrack/services/database_service.dart';

Session _session(String id, DateTime start, {int laps = 2, int rests = 1}) => Session(
      id: id,
      startTime: start,
      poolLengthM: 25,
      durationSec: 120,
      totalDistanceM: laps * 25,
      avgSwolf: 40.0,
      avgStrokeRate: 30.0,
      avgDps: 1.5,
      laps: [
        for (var n = 1; n <= laps; n++)
          Lap(lapNumber: n, strokeCount: 15, timeSeconds: 25.0 + n,
              swolf: 40.0 + n, strokeRate: 30.0, dps: 1.6),
      ],
      rests: [
        for (var r = 0; r < rests; r++) RestInterval(startMs: 1000 * r, durationSec: 5.0),
      ],
    );

void main() {
  sqfliteFfiInit();
  late DatabaseService db;

  setUp(() async {
    db = DatabaseService.withFactory(databaseFactoryFfiNoIsolate);
    await db.initDatabase();
  });

  tearDown(() => db.close());

  test('insert then read back a full session', () async {
    await db.insertSession(_session('a', DateTime(2026, 10, 1, 8)));
    final s = await db.getSession('a');
    expect(s, isNotNull);
    expect(s!.laps, hasLength(2));
    expect(s.laps.map((l) => l.lapNumber), [1, 2]);
    expect(s.laps.last.timeSeconds, 27.0);
    expect(s.rests.single.durationSec, 5.0);
    expect(s.avgDps, 1.5);
    expect(s.startTime, DateTime(2026, 10, 1, 8));
  });

  test('getSession returns null for an unknown id', () async {
    expect(await db.getSession('missing'), isNull);
  });

  test('getAllSessions is newest first', () async {
    await db.insertSession(_session('old', DateTime(2026, 9, 1)));
    await db.insertSession(_session('new', DateTime(2026, 10, 1)));
    await db.insertSession(_session('mid', DateTime(2026, 9, 15)));
    final ids = (await db.getAllSessions()).map((s) => s.id).toList();
    expect(ids, ['new', 'mid', 'old']);
  });

  test('re-inserting a session replaces its laps and rests', () async {
    await db.insertSession(_session('a', DateTime(2026, 10, 1), laps: 4, rests: 2));
    await db.insertSession(_session('a', DateTime(2026, 10, 1), laps: 1, rests: 0));
    final all = await db.getAllSessions();
    expect(all, hasLength(1));
    expect(all.single.laps, hasLength(1));
    expect(all.single.rests, isEmpty);
  });

  test('deleteSession removes the session and its children', () async {
    await db.insertSession(_session('a', DateTime(2026, 10, 1)));
    await db.insertSession(_session('b', DateTime(2026, 10, 2)));
    await db.deleteSession('a');
    expect(await db.getSession('a'), isNull);
    expect((await db.getAllSessions()).map((s) => s.id), ['b']);
  });

  test('using the service before initDatabase throws', () async {
    final fresh = DatabaseService.withFactory(databaseFactoryFfiNoIsolate);
    expect(() => fresh.getAllSessions(), throwsStateError);
  });

  test('a version 1 database is migrated to the current schema', () async {
    final path = '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/v1_${DateTime.now().microsecondsSinceEpoch}.db';
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(path,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await d.execute('CREATE TABLE sessions (id TEXT PRIMARY KEY, start_time TEXT NOT NULL, '
          'pool_length_m INTEGER NOT NULL, duration_sec INTEGER NOT NULL, '
          'total_distance_m INTEGER NOT NULL, avg_swolf REAL NOT NULL, '
          'avg_stroke_rate REAL NOT NULL)');
      await d.execute('CREATE TABLE laps (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'session_id TEXT NOT NULL, lap_number INTEGER NOT NULL, '
          'stroke_count INTEGER NOT NULL, time_seconds REAL NOT NULL, '
          'swolf REAL NOT NULL, stroke_rate REAL NOT NULL)');
      await d.execute('CREATE TABLE rests (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'session_id TEXT NOT NULL, start_ms INTEGER NOT NULL, duration_sec REAL NOT NULL)');
      await d.insert('sessions', {
        'id': 'legacy', 'start_time': DateTime(2026, 4, 1).toIso8601String(),
        'pool_length_m': 25, 'duration_sec': 60, 'total_distance_m': 50,
        'avg_swolf': 45.0, 'avg_stroke_rate': 28.0,
      });
      await d.insert('laps', {
        'session_id': 'legacy', 'lap_number': 1, 'stroke_count': 15,
        'time_seconds': 30.0, 'swolf': 45.0, 'stroke_rate': 28.0,
      });
    }));
    await v1.close();

    final migrated = DatabaseService.withFactory(databaseFactoryFfiNoIsolate, path: path);
    await migrated.initDatabase();
    final s = await migrated.getSession('legacy');
    expect(s, isNotNull);
    expect(s!.avgDps, 0.0);
    expect(s.laps.single.dps, 0.0);
    await migrated.close();
    await databaseFactoryFfiNoIsolate.deleteDatabase(path);
  });
}
