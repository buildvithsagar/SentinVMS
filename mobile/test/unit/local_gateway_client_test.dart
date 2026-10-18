import 'dart:convert';

import 'package:app/features/stream_demo/stream_demo.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  late Dio dio;
  late _MockHttpClientAdapter adapter;
  late LocalGatewayClient client;

  setUp(() {
    dio = Dio();
    adapter = _MockHttpClientAdapter();
    dio.httpClientAdapter = adapter;
    client = LocalGatewayClient(dio: dio);
  });

  test('health preflight accepts a ready gateway', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
      (_) async => ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'active_streams': 0}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    await expectLater(
      client.checkHealth(
        gatewayBaseUri: Uri.parse('http://192.168.1.10:8090'),
        token: 'test-token',
      ),
      completes,
    );
  });

  test('health preflight explains an invalid token', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
      (_) async => ResponseBody.fromString(
        jsonEncode({'error': 'Unauthorized'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    await expectLater(
      client.checkHealth(
        gatewayBaseUri: Uri.parse('http://192.168.1.10:8090'),
        token: 'wrong-token',
      ),
      throwsA(
        isA<LocalGatewayException>().having(
          (error) => error.message,
          'message',
          contains('token is incorrect'),
        ),
      ),
    );
  });
}
