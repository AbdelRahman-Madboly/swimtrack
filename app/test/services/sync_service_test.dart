import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swimtrack/services/database_service.dart';
import 'package:swimtrack/services/device_api_service.dart';
import 'package:swimtrack/services/sync_service.dart';

import '../helpers/fake_device.dart';

void main() {
  sqfliteFfiInit();
  late DatabaseService db;
  late FakeDeviceAdapter adapter;

  SyncService build(Map<String, Object?> routes) {
    adapter = FakeDeviceAdapter(routes);
    return SyncService(
      api: DeviceApiService.withDio(fakeDio(adapter)),
      db: db,
    );
  }

  setUp(() async {
    db = DatabaseService.withFactory(databaseFactoryFfiNoIsolate);
    await db.initDatabase();
  });

  tearDown(() => db.close());

  test('downloads every session the phone does not have yet', () async {
    final sync = build({
      'GET /api/sessions': [deviceSummaryJson(1), deviceSummaryJson(2)],
      'GET /api/sessions/1': deviceSessionJson(1),
      'GET /api/sessions/2': deviceSessionJson(2, laps: 4),
    });
    final result = await sync.sync();
    expect(result.newSessions, 2);
    expect(result.errors, isEmpty);
    expect((await db.getSession('2'))!.laps, hasLength(4));
  });

  test('sessions already stored locally are skipped', () async {
    await build({
      'GET /api/sessions': [deviceSummaryJson(1)],
      'GET /api/sessions/1': deviceSessionJson(1),
    }).sync();

    final sync = build({
      'GET /api/sessions': [deviceSummaryJson(1), deviceSummaryJson(3)],
      'GET /api/sessions/1': deviceSessionJson(1),
      'GET /api/sessions/3': deviceSessionJson(3),
    });
    final result = await sync.sync();
    expect(result.newSessions, 1);
    expect(adapter.calls, ['GET /api/sessions', 'GET /api/sessions/3']);
    expect(await db.getAllSessions(), hasLength(2));
  });

  test('one failed download is reported and the rest still sync', () async {
    final sync = build({
      'GET /api/sessions': [deviceSummaryJson(1), deviceSummaryJson(2)],
      'GET /api/sessions/1': DioExceptionType.receiveTimeout,
      'GET /api/sessions/2': deviceSessionJson(2),
    });
    final result = await sync.sync();
    expect(result.newSessions, 1);
    expect(result.errors.single, contains('session 1'));
    expect(await db.getSession('1'), isNull);
    expect(await db.getSession('2'), isNotNull);
  });

  test('an unreachable device returns an error and stores nothing', () async {
    final sync = build({'GET /api/sessions': DioExceptionType.connectionError});
    final result = await sync.sync();
    expect(result.newSessions, 0);
    expect(result.errors.single, contains('Cannot reach device'));
    expect(await db.getAllSessions(), isEmpty);
  });

  test('an empty device list is a clean no-op', () async {
    final result = await build({'GET /api/sessions': <Object>[]}).sync();
    expect(result.newSessions, 0);
    expect(result.errors, isEmpty);
  });

  test('simulator mode stores generated sessions without HTTP', () async {
    final sync = build({});
    final result = await sync.sync(simulatorMode: true);
    expect(result.newSessions, 3);
    expect(adapter.calls, isEmpty);
    expect(await db.getAllSessions(), hasLength(3));
  });
}
