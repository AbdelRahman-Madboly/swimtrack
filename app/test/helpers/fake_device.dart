// A fake HTTP adapter for Dio that answers like the SwimTrack firmware.
// Routes are matched on "METHOD /path"; anything unknown returns 404.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Object? Function(RequestOptions options);

class FakeDeviceAdapter implements HttpClientAdapter {
  FakeDeviceAdapter(this.routes);

  /// Responses keyed by "GET /api/sessions" etc. A value may be a JSON-able
  /// object, a [FakeHandler], a [FakeStatus], or a [DioExceptionType] to
  /// simulate a network failure.
  final Map<String, Object?> routes;

  /// Every request seen, in order, as "METHOD /path".
  final List<String> calls = [];

  /// Decoded JSON body of the last request that had one.
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    if (options.data != null) {
      lastBody = options.data is String ? jsonDecode(options.data as String) : options.data;
    }

    if (!routes.containsKey(key)) {
      return _json({'error': 'not found'}, 404);
    }
    var value = routes[key];
    if (value is FakeHandler) value = value(options);
    if (value is DioExceptionType) {
      throw DioException(requestOptions: options, type: value);
    }
    if (value is FakeStatus) return _json(value.body, value.code);
    return _json(value, 200);
  }

  ResponseBody _json(Object? body, int code) => ResponseBody.fromString(
        jsonEncode(body),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A response with a non-200 status code.
class FakeStatus {
  const FakeStatus(this.code, this.body);
  final int code;
  final Object? body;
}

Dio fakeDio(FakeDeviceAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://192.168.4.1'))..httpClientAdapter = adapter;

/// A full session in the shape session_manager_part3.cpp writes it.
Map<String, dynamic> deviceSessionJson(int id, {int laps = 2}) => {
      'id': id,
      'start_ms': 120000,
      'end_ms': 186100,
      'duration_s': '66.1',
      'pool_m': 25,
      'laps': laps,
      'total_strokes': 30,
      'total_dist_m': laps * 25,
      'avg_swolf': '41.5',
      'avg_spm': '28.0',
      'avg_dps': '1.67',
      'lap_data': [
        for (var n = 1; n <= laps; n++)
          {'n': n, 't_s': '26.5', 'strokes': 15, 'swolf': '41.5', 'spm': '28.0', 'dps': '1.67'},
      ],
      'rests': [
        {'start_ms': 150000, 'dur_s': '12.0'},
      ],
    };

/// A list entry in the shape GET /api/sessions returns.
Map<String, dynamic> deviceSummaryJson(int id) => {
      'id': id,
      'duration_s': 66.1,
      'laps': 2,
      'total_strokes': 30,
      'pool_m': 25,
      'total_dist_m': 50,
      'avg_swolf': '41.5',
    };
