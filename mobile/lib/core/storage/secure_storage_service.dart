import 'package:flutter/services.dart';

class SecureStorageService {
  static const MethodChannel _channel =
      MethodChannel('com.vms.app/secure_storage');
  static const String _refreshTokenKey = 'vms_refresh_token';

  /// Securely stores the refresh token in the hardware-backed keystore/keychain.
  Future<void> storeRefreshToken(String token) async {
    try {
      await _channel.invokeMethod<void>('write', {
        'key': _refreshTokenKey,
        'value': token,
      });
    } on PlatformException catch (e) {
      throw SecureStorageException(
        'Failed to write refresh token: ${e.message}',
      );
    }
  }

  /// Retrieves the refresh token from secure storage.
  /// Returns null if the token does not exist.
  Future<String?> getRefreshToken() async {
    try {
      return await _channel.invokeMethod<String>('read', {
        'key': _refreshTokenKey,
      });
    } on PlatformException catch (e) {
      throw SecureStorageException('Failed to read refresh token: ${e.message}');
    }
  }

  /// Deletes the refresh token from secure storage.
  Future<void> deleteRefreshToken() async {
    try {
      await _channel.invokeMethod<void>('delete', {
        'key': _refreshTokenKey,
      });
    } on PlatformException catch (e) {
      throw SecureStorageException(
        'Failed to delete refresh token: ${e.message}',
      );
    }
  }

  /// Clears all keys in secure storage.
  Future<void> clearAll() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException catch (e) {
      throw SecureStorageException(
        'Failed to clear secure storage: ${e.message}',
      );
    }
  }
}

class SecureStorageException implements Exception {
  SecureStorageException(this.message);

  final String message;

  @override
  String toString() => 'SecureStorageException: $message';
}
