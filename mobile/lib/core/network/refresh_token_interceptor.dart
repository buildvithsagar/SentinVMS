import 'dart:async';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/auth/auth_event.dart';
import 'package:app/core/auth/auth_state.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';

class RefreshTokenInterceptor extends QueuedInterceptor {
  RefreshTokenInterceptor({
    required this.storage,
    required this.dio,
    required this.authBloc,
  });

  final SecureStorageService storage;
  final Dio dio;
  final AuthBloc authBloc;
  Completer<void>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authState = authBloc.state;
    if (authState is Authenticated) {
      options.headers['Authorization'] = 'Bearer ${authState.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final requestPath = err.requestOptions.path;
    // Don't try to refresh if the failed request itself is login or refresh
    if (requestPath.contains('/auth/login') ||
        requestPath.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    if (_refreshCompleter != null) {
      try {
        await _refreshCompleter!.future;
        final response = await _retry(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
      return;
    }

    _refreshCompleter = Completer<void>();
    try {
      await _performRefresh();
      _refreshCompleter!.complete();
      final response = await _retry(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      _refreshCompleter!.completeError(e);
      // On failed refresh, clean up state and force logout
      authBloc.add(const AuthLoggedOut());
      await storage.deleteRefreshToken();
      handler.next(err);
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _performRefresh() async {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v5/auth/refresh'),
        error: 'No refresh token available in secure storage',
      );
    }

    // Create a clean Dio instance that reuses the same client adapter
    // (carrying intermediate CA pinning and dev bypass) but has no interceptors
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: dio.options.connectTimeout,
        receiveTimeout: dio.options.receiveTimeout,
      ),
    )..httpClientAdapter = dio.httpClientAdapter;

    final response = await refreshDio.post<Map<String, dynamic>>(
      'auth/refresh',
      options: Options(
        headers: <String, dynamic>{
          'Cookie': 'refreshToken=$refreshToken',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Refresh returned empty body',
      );
    }

    final newAccessToken = data['accessToken'] as String?;
    if (newAccessToken == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Refresh response missing accessToken',
      );
    }

    // Check if server rotated the refresh cookie
    final setCookieHeaders = response.headers['set-cookie'];
    final newRefreshToken = _extractVmsRefreshCookie(setCookieHeaders);
    if (newRefreshToken != null) {
      await storage.storeRefreshToken(newRefreshToken);
    }

    // Update AuthBloc with the new token
    authBloc.add(AuthTokenRefreshed(token: newAccessToken));
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final authState = authBloc.state;
    final token = authState is Authenticated ? authState.accessToken : '';

    final opts = Options(
      method: options.method,
      headers: Map<String, dynamic>.from(options.headers)
        ..['Authorization'] = 'Bearer $token',
      responseType: options.responseType,
      contentType: options.contentType,
      validateStatus: options.validateStatus,
      receiveTimeout: options.receiveTimeout,
      sendTimeout: options.sendTimeout,
    );

    return dio.request<dynamic>(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: opts,
    );
  }

  String? _extractVmsRefreshCookie(List<String>? cookies) {
    if (cookies == null) return null;
    for (final cookie in cookies) {
      final parts = cookie.split(';');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('refreshToken=')) {
          return trimmed.substring('refreshToken='.length);
        } else if (trimmed.startsWith('vms_refresh=')) {
          return trimmed.substring('vms_refresh='.length);
        }
      }
    }
    return null;
  }
}
