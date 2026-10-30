class RtspUriParser {
  const RtspUriParser._();

  /// Normalizes URLs copied from camera manuals or VLC.
  ///
  /// CCTV passwords commonly contain a raw `@`. Only the final `@` in the
  /// authority separates credentials from the host, so earlier occurrences
  /// are encoded as part of user-info. Existing percent-encoding is preserved.
  static String normalize(String value) {
    final input = value.trim();
    final match = RegExp(
      r'^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/(.*)$',
      dotAll: true,
    ).firstMatch(input);
    if (match == null) return input;

    final scheme = match.group(1)!.toLowerCase();
    final remainder = match.group(2)!;
    final authorityEnd = _authorityEnd(remainder);
    final authority = remainder.substring(0, authorityEnd);
    final suffix = remainder.substring(authorityEnd);
    final lastAt = authority.lastIndexOf('@');
    if (lastAt < 0) return '$scheme://$authority$suffix';

    final userInfo = authority.substring(0, lastAt);
    final hostAndPort = authority.substring(lastAt + 1);
    final passwordSeparator = userInfo.indexOf(':');
    final normalizedUserInfo = passwordSeparator < 0
        ? _encodeUserInfoPart(userInfo)
        : '${_encodeUserInfoPart(userInfo.substring(0, passwordSeparator))}:'
              '${_encodeUserInfoPart(userInfo.substring(passwordSeparator + 1))}';
    return '$scheme://$normalizedUserInfo@$hostAndPort$suffix';
  }

  static String? validate(String? value) {
    final input = normalize(value ?? '');
    if (input.isEmpty) return 'Enter the camera RTSP URL.';
    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      return 'Enter a complete URL including protocol and host.';
    }
    if (uri.scheme != 'rtsp' && uri.scheme != 'rtsps') {
      return 'Use an rtsp:// or rtsps:// camera URL.';
    }
    return null;
  }

  static Uri? tryParse(String value) {
    if (validate(value) != null) return null;
    return Uri.tryParse(normalize(value));
  }

  /// Safe label for UI/logging that never includes camera credentials.
  static String sanitizedLabel(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }

  static int _authorityEnd(String value) {
    final indexes = <int>[
      value.indexOf('/'),
      value.indexOf('?'),
      value.indexOf('#'),
    ].where((index) => index >= 0);
    if (indexes.isEmpty) return value.length;
    return indexes.reduce((left, right) => left < right ? left : right);
  }

  static String _encodeUserInfoPart(String value) {
    try {
      return Uri.encodeComponent(Uri.decodeComponent(value));
    } on FormatException {
      return Uri.encodeComponent(value);
    }
  }
}
