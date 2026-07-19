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



  Future<String> loginStep1({
    required String email,
    required String password,
  }) async {
    // Detached from backend: Return OTP_SENT instantly
    return 'OTP_SENT';
  }

  Future<AuthResult> loginStep2({
    required String email,
    required String otpCode,
    required String customerId,
  }) async {
    // Detached from backend: Return mock AuthResult instantly
    return AuthResult(
      accessToken: 'mock_jwt_token_for_demo_operator',
      user: UserProfile(
        userId: 'usr-demo-operator',
        customerId: customerId.isNotEmpty ? customerId : 'demo_tenant',
        username: email.isNotEmpty ? email : 'operator@demo.com',
        baseRole: 'OPERATOR',
      ),
    );
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
    try {
      dio.post<void>('auth/logout').catchError((Object err) {
        return Response<void>(requestOptions: RequestOptions(path: 'auth/logout'));
      });
    } catch (_) {}
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
