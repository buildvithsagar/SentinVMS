import 'package:app/features/stream_demo/models/local_gateway_session.dart';
import 'package:dio/dio.dart';

class LocalGatewayClient {
  LocalGatewayClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              // Gateway may spend up to 15s probing and 25s starting media.
              // Keep the client deadline above that server-side contract.
              receiveTimeout: const Duration(seconds: 50),
            ),
          );

  final Dio _dio;

  Future<void> checkHealth({required Uri gatewayBaseUri, String? token}) async {
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        _endpoint(gatewayBaseUri, 'health'),
        options: Options(headers: _headers(token)),
      );
      if (response.data?['status'] != 'ok') {
        throw const LocalGatewayException(
          'The gateway responded, but it is not ready.',
        );
      }
    } on DioException catch (error) {
      throw LocalGatewayException(_connectionMessage(error));
    }
  }

  Future<LocalGatewaySession> createStream({
    required Uri gatewayBaseUri,
    required Uri rtspUri,
    required bool compatibilityMode,
    String? token,
  }) async {
    final endpoint = _endpoint(gatewayBaseUri, 'api/v1/streams');
    try {
      final response = await _dio.postUri<Map<String, dynamic>>(
        endpoint,
        data: {
          'rtsp_url': rtspUri.toString(),
          // Auto keeps H.264 as pass-through and converts H.265 only when
          // compatibility mode is enabled. Turning it off requests pass-through.
          'transcode': compatibilityMode ? 'auto' : 'never',
        },
        options: Options(headers: _headers(token)),
      );
      final data = response.data;
      if (data == null) {
        throw const LocalGatewayException(
          'Gateway returned an empty response.',
        );
      }
      return LocalGatewaySession.fromJson(data);
    } on DioException catch (error) {
      final responseData = error.response?.data;
      final message = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;
      throw LocalGatewayException(message ?? _connectionMessage(error));
    } on FormatException catch (error) {
      throw LocalGatewayException(error.message);
    }
  }

  Future<void> stopStream({
    required Uri gatewayBaseUri,
    required String streamId,
    String? token,
  }) async {
    try {
      await _dio.deleteUri<void>(
        _endpoint(gatewayBaseUri, 'api/v1/streams/$streamId'),
        options: Options(headers: _headers(token)),
      );
    } catch (_) {
      // The container also cleans up FFmpeg if the gateway is stopped.
    }
  }

  Uri _endpoint(Uri base, String path) {
    final normalized = base.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$normalized/$path');
  }

  Map<String, String> _headers(String? token) => {
    if (token != null && token.trim().isNotEmpty)
      'Authorization': 'Bearer ${token.trim()}',
  };

  String _connectionMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return 'Gateway token is incorrect. Copy the current token from the gateway .env file.';
    }
    if (statusCode == 429) {
      return 'The gateway is already using all available stream slots. Stop an old stream and retry.';
    }
    if (statusCode == 502 || statusCode == 504) {
      return 'The gateway is running, but it cannot reach the camera. Check the RTSP URL, credentials, and camera network.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Gateway is unreachable. Keep the phone and computer on the same Wi-Fi and use the computer LAN IP, not localhost.';
    }
    return 'Cannot connect to the local media gateway.';
  }
}

class LocalGatewayException implements Exception {
  const LocalGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}
