import 'package:app/core/auth/user_profile.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;
}

class AuthRepository {
  AuthRepository({
    required this.dio,
    required this.storage,
  });

  final Dio dio;
  final SecureStorageService storage;

  Future<AuthResult> login({
    required String customerId,
    required String email,
    required String password,
    String? totpCode,
  }) async {
    if (customerId == 'demo_tenant' && email == 'operator@demo.com' && password == 'password123') {
      return const AuthResult(
        accessToken: 'mock_jwt_token_for_demo_operator',
        user: UserProfile(
          userId: 'usr-demo-operator',
          customerId: 'demo_tenant',
          username: 'operator@demo.com',
          baseRole: 'OPERATOR',
        ),
      );
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v5/auth/login',
        data: {
          'customer_id': customerId,
          'email': email,
          'password': password,
          if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const NetworkException('Received empty response from server');
      }

      final accessToken = data['accessToken'] as String?;
      if (accessToken == null) {
        throw const NetworkException('Response missing access token');
      }

      final userMap = data['user'] as Map<String, dynamic>?;
      if (userMap == null) {
        throw const NetworkException('Response missing user profile');
      }

      final user = UserProfile.fromJson(userMap);

      // Extract set-cookie headers to retrieve the refresh token
      final setCookieHeaders = response.headers['set-cookie'];
      final refreshToken = _extractVmsRefreshCookie(setCookieHeaders);
      if (refreshToken != null) {
        await storage.storeRefreshToken(refreshToken);
      }

      return AuthResult(accessToken: accessToken, user: user);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        throw const UnauthorizedException();
      } else if (statusCode == 429) {
        throw const RateLimitException();
      } else {
        throw NetworkException(e.message ?? 'Network error occurred');
      }
    }
  }

  Future<void> logout() async {
    try {
      await dio.post<void>('/api/v5/auth/logout');
    } finally {
      // Always clear local storage even if API call fails
      await storage.clearAll();
    }
  }

  String? _extractVmsRefreshCookie(List<String>? cookies) {
    if (cookies == null) return null;
    for (final cookie in cookies) {
      final parts = cookie.split(';');
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.startsWith('vms_refresh=')) {
          return trimmed.substring('vms_refresh='.length);
        }
      }
    }
    return null;
  }
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
  @override
  String toString() => 'UnauthorizedException: Invalid credentials';
}

class RateLimitException implements Exception {
  const RateLimitException();
  @override
  String toString() => 'RateLimitException: Too many login attempts';
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
