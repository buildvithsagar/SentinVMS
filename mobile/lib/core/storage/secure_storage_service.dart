import 'package:flutter/services.dart';

abstract interface class SecureKeyValueStore {
  Future<void> writeSecureValue(String key, String value);

  Future<String?> readSecureValue(String key);

  Future<void> deleteSecureValue(String key);
}

class SecureStorageService implements SecureKeyValueStore {
  static const MethodChannel _channel = MethodChannel(
    'com.vms.app/secure_storage',
  );
  static const String _refreshTokenKey = 'vms_refresh_token';

  /// Securely stores the refresh token in the hardware-backed keystore/keychain.
  Future<void> storeRefreshToken(String token) async {
    await writeSecureValue(_refreshTokenKey, token);
  }

  @override
  Future<void> writeSecureValue(String key, String value) async {
    try {
      await _channel.invokeMethod<void>('write', {'key': key, 'value': value});
    } on PlatformException catch (e) {
      throw SecureStorageException(
        'Failed to write refresh token: ${e.message}',
      );
    }
  }

  /// Retrieves the refresh token from secure storage.
  /// Returns null if the token does not exist.
  Future<String?> getRefreshToken() async {
    return readSecureValue(_refreshTokenKey);
  }

  @override
  Future<String?> readSecureValue(String key) async {
    try {
      return await _channel.invokeMethod<String>('read', {'key': key});
    } on PlatformException catch (e) {
      throw SecureStorageException(
        'Failed to read refresh token: ${e.message}',
      );
    }
  }

  /// Deletes the refresh token from secure storage.
  Future<void> deleteRefreshToken() async {
    await deleteSecureValue(_refreshTokenKey);
  }

  @override
  Future<void> deleteSecureValue(String key) async {
    try {
      await _channel.invokeMethod<void>('delete', {'key': key});
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
