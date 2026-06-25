import 'dart:convert';
import 'dart:io';
import 'package:app/core/auth/auth_bloc.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/network/refresh_token_interceptor.dart';
import 'package:app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class DioFactory {
  DioFactory._();

  /// Create and configure a Dio instance with SPKI intermediate CA pinning
  /// and local dev bypass.
  static Dio create({
    required SecureStorageService storage,
    required AuthBloc authBloc, // Inject AuthBloc
    required List<String> trustedCAsPem, // Intermediate CA PEM certificates
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: const <String, dynamic>{'Content-Type': 'application/json'},
      ),
    );

    // Determine if we should bypass pinning (compile-time flag)
    const bypassPinning = bool.fromEnvironment('BYPASS_PINNING');

    // Configure the HttpClient adapter
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final SecurityContext securityContext;

        if (bypassPinning) {
          // In local dev bypass mode, trust all system certificates
          securityContext = SecurityContext.defaultContext;
        } else {
          // Initialize a clean SecurityContext and ONLY trust our Intermediate CA(s)
          securityContext = SecurityContext();
          for (final pem in trustedCAsPem) {
            if (pem.trim().isNotEmpty) {
              securityContext.setTrustedCertificatesBytes(utf8.encode(pem));
            }
          }
        }

        final client = HttpClient(context: securityContext);

        if (bypassPinning) {
          // In local dev bypass mode, allow self-signed certificates (e.g. local emulators)
          client.badCertificateCallback = (cert, host, port) => true;
        } else {
          // Strictly reject any bad certificates
          client.badCertificateCallback = (cert, host, port) => false;
        }

        return client;
      },
    );

    // Add interceptors
    dio.interceptors.addAll([
      RefreshTokenInterceptor(storage: storage, dio: dio, authBloc: authBloc),
      // Never log sensitive raw token bytes to console output
      LogInterceptor(requestHeader: false, responseHeader: false),
    ]);

    return dio;
  }
}
