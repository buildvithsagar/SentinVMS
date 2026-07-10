import 'dart:convert';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/auth/user_profile.dart';
import 'package:app/core/network/refresh_token_interceptor.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions());
  });

  group('RefreshTokenInterceptor', () {
    late SecureStorageService storage;
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late AuthBloc authBloc;

    setUp(() {
      storage = MockSecureStorageService();
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v5'));
      mockAdapter = MockHttpClientAdapter();
      dio.httpClientAdapter = mockAdapter;
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('onRequest injects Authorization header when Authenticated', () async {
      authBloc.add(
        const AuthLoggedIn(
          accessToken: 'initial-access-token',
          user: UserProfile(
            userId: '1',
            customerId: 'tenant',
            username: 'user',
            baseRole: 'OPERATOR',
          ),
        ),
      );

      // Yield to event loop to allow AuthBloc to process the event
      await Future<void>.delayed(Duration.zero);

      final interceptor = RefreshTokenInterceptor(
        storage: storage,
        dio: dio,
        authBloc: authBloc,
      );
      final options = RequestOptions();
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], 'Bearer initial-access-token');
    });

    test('onError attempts refresh on 401 Unauthorized', () async {
      when(() => storage.getRefreshToken())
          .thenAnswer((_) async => 'old-refresh-token');
      when(() => storage.storeRefreshToken(any())).thenAnswer((_) async {});
      when(() => storage.deleteRefreshToken()).thenAnswer((_) async {});

      final refreshResponse = ResponseBody.fromString(
        jsonEncode({'accessToken': 'new-access-token'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'set-cookie': ['vms_refresh=new-refresh-token; Path=/'],
        },
      );

      final retryResponse = ResponseBody.fromString(
        jsonEncode({'data': 'success'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

      var callCount = 0;
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        callCount++;
        final options = invocation.positionalArguments[0] as RequestOptions;
        if (options.path.contains('auth/refresh')) {
          return refreshResponse;
        } else if (callCount == 1) {
          return ResponseBody.fromString('', 401);
        } else {
          return retryResponse;
        }
      });

      authBloc.add(
        const AuthLoggedIn(
          accessToken: 'expired-access-token',
          user: UserProfile(
            userId: '1',
            customerId: 'tenant',
            username: 'user',
            baseRole: 'OPERATOR',
          ),
        ),
      );

      // Yield to event loop to allow AuthBloc to process the event
      await Future<void>.delayed(Duration.zero);

      dio.interceptors.add(
        RefreshTokenInterceptor(
          storage: storage,
          dio: dio,
          authBloc: authBloc,
        ),
      );

      final response = await dio.get<Map<String, dynamic>>('/some-endpoint');

      expect(response.statusCode, 200);
      expect(response.data?['data'], 'success');
      expect(
        (authBloc.state as Authenticated).accessToken,
        'new-access-token',
      );
      verify(() => storage.storeRefreshToken('new-refresh-token')).called(1);
    });
  });
}
