import 'dart:convert';

enum DeviceCodePayloadFormat { plainSerial, json, uri, keyValue, unsupported }

class DeviceCodePayload {
  const DeviceCodePayload({
    required this.rawValue,
    required this.format,
    this.serialNumber,
    this.deviceName,
    this.username,
    this.ipAddress,
    this.rtspUrl,
    this.vendor,
    this.model,
  });

  final String rawValue;
  final DeviceCodePayloadFormat format;
  final String? serialNumber;
  final String? deviceName;
  final String? username;
  final String? ipAddress;
  final String? rtspUrl;
  final String? vendor;
  final String? model;

  bool get hasDeviceIdentity => serialNumber?.isNotEmpty ?? false;

  bool get containsRtspUrl => rtspUrl?.isNotEmpty ?? false;

  String get formatLabel => switch (format) {
    DeviceCodePayloadFormat.plainSerial => 'barcode',
    DeviceCodePayloadFormat.json => 'JSON QR',
    DeviceCodePayloadFormat.uri => 'pairing URL',
    DeviceCodePayloadFormat.keyValue => 'device label',
    DeviceCodePayloadFormat.unsupported => 'unrecognized code',
  };
}

class DeviceCodePayloadParser {
  const DeviceCodePayloadParser();

  static const _serialKeys = <String>{
    'sn',
    'serial',
    'serialno',
    'serialnumber',
    'deviceserial',
    'devicesn',
    'uid',
    'deviceuid',
    'p2pid',
    'cloudid',
    'deviceid',
    'devicenumber',
    'did',
    'id',
  };
  static const _nameKeys = <String>{
    'name',
    'devicename',
    'cameraname',
    'label',
  };
  static const _usernameKeys = <String>{'user', 'username', 'login'};
  static const _ipKeys = <String>{
    'ip',
    'ipaddress',
    'address',
    'host',
    'hostname',
  };
  static const _rtspKeys = <String>{
    'rtsp',
    'rtspurl',
    'stream',
    'streamurl',
    'url',
  };
  static const _vendorKeys = <String>{
    'vendor',
    'brand',
    'manufacturer',
    'make',
  };
  static const _modelKeys = <String>{'model', 'modelname', 'devicemodel'};
  static const _embeddedPayloadKeys = <String>{'data', 'payload', 'device'};

  DeviceCodePayload parse(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) {
      return const DeviceCodePayload(
        rawValue: '',
        format: DeviceCodePayloadFormat.unsupported,
      );
    }

    if (raw.toUpperCase().startsWith('WIFI:')) {
      return DeviceCodePayload(
        rawValue: raw,
        format: DeviceCodePayloadFormat.unsupported,
      );
    }

    final jsonValues = _parseJson(raw);
    if (jsonValues.isNotEmpty) {
      return _fromValues(
        raw: raw,
        format: DeviceCodePayloadFormat.json,
        values: jsonValues,
      );
    }

    final uri = _parseUri(raw);
    if (uri != null) {
      return _fromUri(raw, uri);
    }

    final keyValuePairs = _parseKeyValuePairs(raw);
    if (keyValuePairs.isNotEmpty) {
      return _fromValues(
        raw: raw,
        format: DeviceCodePayloadFormat.keyValue,
        values: keyValuePairs,
      );
    }

    if (_looksLikeSerial(raw)) {
      return DeviceCodePayload(
        rawValue: raw,
        format: DeviceCodePayloadFormat.plainSerial,
        serialNumber: raw,
      );
    }

    return DeviceCodePayload(
      rawValue: raw,
      format: DeviceCodePayloadFormat.unsupported,
    );
  }

  DeviceCodePayload _fromUri(String raw, Uri uri) {
    final values = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      values[_normalizeKey(entry.key)] = entry.value.trim();
    }

    for (final key in _embeddedPayloadKeys) {
      final embedded = values[key];
      if (embedded != null) {
        values.addAll(_parseJson(embedded));
      }
    }

    final pathSerial = _serialFromPath(uri.pathSegments);
    if (pathSerial != null) values.putIfAbsent('sn', () => pathSerial);

    final isRtsp =
        uri.scheme.toLowerCase() == 'rtsp' ||
        uri.scheme.toLowerCase() == 'rtsps';
    if (isRtsp) {
      values['rtspurl'] = raw;
      if (uri.host.isNotEmpty) values.putIfAbsent('ip', () => uri.host);
      final userInfo = uri.userInfo;
      if (userInfo.isNotEmpty) {
        final separator = userInfo.indexOf(':');
        final encodedUsername = separator < 0
            ? userInfo
            : userInfo.substring(0, separator);
        values.putIfAbsent(
          'username',
          () => Uri.decodeComponent(encodedUsername),
        );
      }
    }

    return _fromValues(
      raw: raw,
      format: DeviceCodePayloadFormat.uri,
      values: values,
      fallbackIpAddress: isRtsp && uri.host.isNotEmpty ? uri.host : null,
      fallbackRtspUrl: isRtsp ? raw : null,
    );
  }

  DeviceCodePayload _fromValues({
    required String raw,
    required DeviceCodePayloadFormat format,
    required Map<String, String> values,
    String? fallbackIpAddress,
    String? fallbackRtspUrl,
  }) {
    final serialNumber = _firstValue(values, _serialKeys);
    final vendor = _firstValue(values, _vendorKeys);
    final model = _firstValue(values, _modelKeys);
    final suppliedName = _firstValue(values, _nameKeys);
    final generatedName = [
      vendor,
      model,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    final rtspCandidate = _firstValue(values, _rtspKeys);
    final rtspUrl = _isRtspUrl(rtspCandidate) ? rtspCandidate : fallbackRtspUrl;

    return DeviceCodePayload(
      rawValue: raw,
      format: format,
      serialNumber: _cleanValue(serialNumber),
      deviceName: _cleanValue(
        suppliedName ?? (generatedName.isEmpty ? null : generatedName),
      ),
      username: _cleanValue(_firstValue(values, _usernameKeys)),
      ipAddress: _cleanValue(_firstValue(values, _ipKeys) ?? fallbackIpAddress),
      rtspUrl: _cleanValue(rtspUrl),
      vendor: _cleanValue(vendor),
      model: _cleanValue(model),
    );
  }

  Map<String, String> _parseJson(String raw) {
    final trimmed = raw.trim();
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return const {};
    }

    try {
      final Object? decoded = jsonDecode(trimmed);
      final values = <String, String>{};
      _collectJsonValues(decoded, values);
      return values;
    } on FormatException {
      return const {};
    }
  }

  void _collectJsonValues(Object? value, Map<String, String> output) {
    if (value is Map<Object?, Object?>) {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) continue;
        final child = entry.value;
        if (child is String || child is num) {
          final normalizedKey = _normalizeKey(key);
          final text = child.toString().trim();
          if (normalizedKey.isNotEmpty && text.isNotEmpty) {
            output.putIfAbsent(normalizedKey, () => text);
          }
        } else {
          _collectJsonValues(child, output);
        }
      }
    } else if (value is List<Object?>) {
      for (final item in value) {
        _collectJsonValues(item, output);
      }
    }
  }

  Map<String, String> _parseKeyValuePairs(String raw) {
    final values = <String, String>{};
    final matches = RegExp(
      r'(?:^|[;,\n|&])\s*([A-Za-z][A-Za-z0-9 _-]{0,30})\s*[:=]\s*([^;,\n|&]+)',
    ).allMatches(raw);
    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2);
      if (key == null || value == null) continue;
      final normalizedKey = _normalizeKey(key);
      final cleaned = _stripQuotes(value.trim());
      if (normalizedKey.isNotEmpty && cleaned.isNotEmpty) {
        values.putIfAbsent(normalizedKey, () => cleaned);
      }
    }
    return values;
  }

  Uri? _parseUri(String raw) {
    if (!raw.contains('://')) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme.isEmpty) return null;
    return uri;
  }

  String? _serialFromPath(List<String> segments) {
    const identitySegments = <String>{
      'device',
      'devices',
      'pair',
      'pairing',
      'activate',
      'activation',
      'sn',
      'serial',
      'uid',
    };
    for (var index = 0; index < segments.length - 1; index++) {
      if (identitySegments.contains(segments[index].toLowerCase())) {
        final candidate = Uri.decodeComponent(segments[index + 1]).trim();
        if (_looksLikeSerial(candidate)) return candidate;
      }
    }
    return null;
  }

  String? _firstValue(Map<String, String> values, Set<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  bool _looksLikeSerial(String value) {
    if (value.length < 3 || value.length > 128) return false;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(value);
  }

  bool _isRtspUrl(String? value) {
    if (value == null) return false;
    final scheme = Uri.tryParse(value)?.scheme.toLowerCase();
    return scheme == 'rtsp' || scheme == 'rtsps';
  }

  String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  String _stripQuotes(String value) {
    if (value.length < 2) return value;
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1).trim();
    }
    return value;
  }

  String? _cleanValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
