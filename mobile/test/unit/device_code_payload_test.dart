import 'package:app/features/device_onboarding/device_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DeviceCodePayloadParser();

  group('DeviceCodePayloadParser', () {
    test('accepts a plain serial from a QR or Code 128 barcode', () {
      final payload = parser.parse('DS-2CD2143G0-ABC123');

      expect(payload.format, DeviceCodePayloadFormat.plainSerial);
      expect(payload.serialNumber, 'DS-2CD2143G0-ABC123');
      expect(payload.hasDeviceIdentity, isTrue);
    });

    test('extracts supported fields from nested JSON', () {
      final payload = parser.parse('''
        {
          "device": {
            "serialNumber": "HK-998877",
            "name": "Main Gate",
            "manufacturer": "Hikvision",
            "model": "DS-2CD2143G0-I",
            "username": "installer",
            "password": "must-not-be-used"
          },
          "network": {"ipAddress": "192.168.1.108"}
        }
      ''');

      expect(payload.format, DeviceCodePayloadFormat.json);
      expect(payload.serialNumber, 'HK-998877');
      expect(payload.deviceName, 'Main Gate');
      expect(payload.vendor, 'Hikvision');
      expect(payload.model, 'DS-2CD2143G0-I');
      expect(payload.username, 'installer');
      expect(payload.ipAddress, '192.168.1.108');
    });

    test('extracts a device ID and decoded name from a pairing URL', () {
      final payload = parser.parse(
        'https://pair.example/device?deviceId=CP-12345&name=Front%20Door',
      );

      expect(payload.format, DeviceCodePayloadFormat.uri);
      expect(payload.serialNumber, 'CP-12345');
      expect(payload.deviceName, 'Front Door');
      expect(payload.ipAddress, isNull);
    });

    test('extracts a serial from a recognized pairing path', () {
      final payload = parser.parse(
        'https://pair.example/devices/DAHUA-778899/activate',
      );

      expect(payload.serialNumber, 'DAHUA-778899');
    });

    test('extracts fields from a delimited device label', () {
      final payload = parser.parse(
        'SN:CP-445566;MODEL:CP-UNC-TA40;USER=admin;IP=192.168.1.25',
      );

      expect(payload.format, DeviceCodePayloadFormat.keyValue);
      expect(payload.serialNumber, 'CP-445566');
      expect(payload.deviceName, 'CP-UNC-TA40');
      expect(payload.username, 'admin');
      expect(payload.ipAddress, '192.168.1.25');
    });

    test('extracts JSON embedded in a pairing URL payload parameter', () {
      final encoded = Uri.encodeQueryComponent(
        '{"uid":"P2P-10101","brand":"Dahua","model":"IPC-HFW"}',
      );
      final payload = parser.parse('dahua://pair?payload=$encoded');

      expect(payload.serialNumber, 'P2P-10101');
      expect(payload.vendor, 'Dahua');
      expect(payload.deviceName, 'Dahua IPC-HFW');
    });

    test('recognizes an RTSP URL without treating it as a serial', () {
      final payload = parser.parse(
        'rtsp://admin:secret@192.168.1.20:554/Streaming/Channels/101',
      );

      expect(payload.format, DeviceCodePayloadFormat.uri);
      expect(payload.hasDeviceIdentity, isFalse);
      expect(payload.containsRtspUrl, isTrue);
      expect(payload.username, 'admin');
      expect(payload.ipAddress, '192.168.1.20');
    });

    test('does not mistake a Wi-Fi setup QR for a camera identity', () {
      final payload = parser.parse('WIFI:T:WPA;S:Camera_Setup;P:secret;;');

      expect(payload.hasDeviceIdentity, isFalse);
      expect(payload.format, DeviceCodePayloadFormat.unsupported);
    });

    test('returns unsupported for empty or free-form content', () {
      expect(parser.parse('  ').hasDeviceIdentity, isFalse);
      expect(
        parser.parse('Open the vendor app to pair this camera').format,
        DeviceCodePayloadFormat.unsupported,
      );
    });
  });
}
