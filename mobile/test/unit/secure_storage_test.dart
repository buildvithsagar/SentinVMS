import 'package:app/core/storage/secure_storage_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    late SecureStorageService storageService;
    final log = <MethodCall>[];
    const channel = MethodChannel('com.vms.app/secure_storage');
    String? mockStorageValue;

    setUp(() {
      storageService = SecureStorageService();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'write':
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            if (args['key'] == 'vms_refresh_token') {
              mockStorageValue = args['value'] as String?;
            }
            return null;
          case 'read':
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            if (args['key'] == 'vms_refresh_token') {
              return mockStorageValue;
            }
            return null;
          case 'delete':
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            if (args['key'] == 'vms_refresh_token') {
              mockStorageValue = null;
            }
            return null;
          case 'clear':
            mockStorageValue = null;
            return null;
          default:
            return null;
        }
      });
      log.clear();
      mockStorageValue = null;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('storeRefreshToken calls native channel with write', () async {
      await storageService.storeRefreshToken('my-token');
      expect(log, hasLength(1));
      expect(log.first.method, 'write');
      expect(log.first.arguments, {
        'key': 'vms_refresh_token',
        'value': 'my-token',
      });
      expect(mockStorageValue, 'my-token');
    });

    test('getRefreshToken calls native channel with read and returns value',
        () async {
      mockStorageValue = 'another-token';
      final value = await storageService.getRefreshToken();
      expect(log, hasLength(1));
      expect(log.first.method, 'read');
      expect(log.first.arguments, {
        'key': 'vms_refresh_token',
      });
      expect(value, 'another-token');
    });

    test('deleteRefreshToken calls native channel with delete', () async {
      mockStorageValue = 'delete-me';
      await storageService.deleteRefreshToken();
      expect(log, hasLength(1));
      expect(log.first.method, 'delete');
      expect(log.first.arguments, {
        'key': 'vms_refresh_token',
      });
      expect(mockStorageValue, null);
    });

    test('clearAll calls native channel with clear', () async {
      mockStorageValue = 'clear-me';
      await storageService.clearAll();
      expect(log, hasLength(1));
      expect(log.first.method, 'clear');
      expect(mockStorageValue, null);
    });
  });
}
