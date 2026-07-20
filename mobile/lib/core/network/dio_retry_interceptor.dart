import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class DioRetryInterceptor extends Interceptor {
  DioRetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;
  final Logger _logger;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final retryCount = extra['retry_count'] as int? ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      final nextAttempt = retryCount + 1;
      final delay = nextAttempt <= retryDelays.length
          ? retryDelays[nextAttempt - 1]
          : retryDelays.last;

      _logger.w(
        'DioRetryInterceptor: Retrying request [${err.requestOptions.path}] '
        'Attempt $nextAttempt/$maxRetries after ${delay.inSeconds}s delay. Error: ${err.type}',
      );

      await Future<void>.delayed(delay);

      err.requestOptions.extra['retry_count'] = nextAttempt;

      try {
        final response = await dio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (retryErr) {
        return super.onError(retryErr, handler);
      } catch (e) {
        return super.onError(err, handler);
      }
    }

    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    if (err.error is SocketException) {
      return true;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null && (statusCode == 502 || statusCode == 503 || statusCode == 504)) {
      return true;
    }

    return false;
  }
}
