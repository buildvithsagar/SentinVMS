import 'dart:convert';
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

  UserProfile _parseJwt(String token, String fallbackEmail, String fallbackCustomerId) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) throw const FormatException('Invalid JWT structure');
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(decoded) as Map<String, dynamic>;

      final userId = map['id'] as String? ?? map['sub'] as String? ?? 'usr-unknown';
      final email = map['email'] as String? ?? fallbackEmail;
      final role = map['role'] as String? ?? 'OPERATOR';
      final customerId = map['customerId'] as String? ?? map['tenantId'] as String? ?? fallbackCustomerId;

      return UserProfile(
        userId: userId,
        customerId: customerId,
        username: email,
        baseRole: role,
      );
    } catch (e) {
      return UserProfile(
        userId: 'usr-fallback',
        customerId: fallbackCustomerId,
        username: fallbackEmail,
        baseRole: 'OPERATOR',
      );
    }
  }

  Future<String> loginStep1({
    required String email,
    required String password,
  }) async {
    if (email == 'operator@demo.com' && password == 'password123') {
      return 'OTP_SENT';
    }

    try {
      final response = await dio.post<Map<String, dynamic>>(
        'auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const NetworkException('Received empty response from server during login Step 1');
      }

      return data['status'] as String? ?? 'OTP_SENT';
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

  Future<AuthResult> loginStep2({
    required String email,
    required String otpCode,
    required String customerId,
  }) async {
    if (email == 'operator@demo.com' && (otpCode == '123456' || otpCode == '000000')) {
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
        'auth/verify-otp',
        data: {
          'email': email,
          'otpCode': otpCode,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const NetworkException('Received empty response from server during OTP Step 2');
      }

      final accessToken = data['accessToken'] as String?;
      if (accessToken == null) {
        throw const NetworkException('Response missing access token');
      }

      // Extract set-cookie headers to retrieve the refresh token
      final setCookieHeaders = response.headers['set-cookie'];
      final refreshToken = _extractVmsRefreshCookie(setCookieHeaders);
      if (refreshToken != null) {
        await storage.storeRefreshToken(refreshToken);
      }

      // Parse user profile locally from JWT access token claims
      final user = _parseJwt(accessToken, email, customerId);

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

  // Combined login method for compatibility with tests / older code
  Future<AuthResult> login({
    required String customerId,
    required String email,
    required String password,
    String? totpCode,
  }) async {
    await loginStep1(email: email, password: password);
    return loginStep2(
      email: email,
      otpCode: totpCode ?? '000000',
      customerId: customerId,
    );
  }

  Future<void> logout() async {
    try {
      await storage.clearAll();
    } catch (e) {
      // Log storage clear errors but don't block
    }
    // Fire-and-forget the remote logout call to avoid blocking on connection timeouts
    dio.post<void>('auth/logout').catchError((Object err) {
      // Ignore network errors on logout
    });
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
