import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'ffmpeg_command_builder.dart';
import 'gateway_config.dart';
import 'stream_models.dart';

class StreamManager {
  StreamManager({required this.config, Random? random})
    : _random = random ?? Random.secure() {
    _reaper = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reapExpiredStreams(),
    );
  }

  final GatewayConfig config;
  final Random _random;
  final Map<String, _ManagedStream> _streams = {};
  final HttpClient _httpClient = HttpClient();
  late final Timer _reaper;

  Iterable<GatewayStreamInfo> get streams =>
      _streams.values.map((stream) => stream.info);

  GatewayStreamInfo? get(String id) => _streams[id]?.info;

  Future<GatewayStreamInfo> create(CreateStreamRequest request) async {
    final activeCount = _streams.values
        .where(
          (stream) =>
              stream.info.state == GatewayStreamState.starting ||
              stream.info.state == GatewayStreamState.ready,
        )
        .length;
    if (activeCount >= config.maxStreams) {
      throw GatewayRequestException(
        'Maximum active stream limit (${config.maxStreams}) reached.',
        statusCode: 429,
      );
    }

    final codec = await _probeCodec(request.rtspUri);
    final id = _newId();
    final destination =
        '${config.mediaMtxRtspBase.replaceFirst(RegExp(r'/+$'), '')}/$id';
    final command = FfmpegCommandBuilder.build(
      source: request.rtspUri,
      destination: destination,
      sourceCodec: codec,
      policy: request.transcodePolicy,
    );
    final process = await Process.start(
      config.ffmpegPath,
      command.arguments,
      runInShell: false,
    );
    final managed = _ManagedStream(
      process: process,
      createdAt: DateTime.now(),
      info: GatewayStreamInfo(
        id: id,
        state: GatewayStreamState.starting,
        sourceCodec: _canonicalCodec(codec),
        deliveryCodec: 'H264',
        transcoded: command.transcoded,
      ),
    );
    _streams[id] = managed;
    unawaited(_captureProcessExit(managed));
    unawaited(process.stdout.drain<void>());
    unawaited(
      process.stderr.transform(utf8.decoder).listen((_) {}).asFuture<void>(),
    );

    try {
      await _waitUntilReady(id, process);
      managed.info = GatewayStreamInfo(
        id: id,
        state: GatewayStreamState.ready,
        sourceCodec: managed.info.sourceCodec,
        deliveryCodec: managed.info.deliveryCodec,
        transcoded: managed.info.transcoded,
      );
      return managed.info;
    } catch (error) {
      process.kill();
      _streams.remove(id);
      managed.info = GatewayStreamInfo(
        id: id,
        state: GatewayStreamState.failed,
        sourceCodec: managed.info.sourceCodec,
        deliveryCodec: managed.info.deliveryCodec,
        transcoded: managed.info.transcoded,
        message: 'Stream did not become ready before the timeout.',
      );
      throw GatewayRequestException(
        'Unable to start the CCTV stream. Verify URL, credentials, and network reachability.',
        statusCode: 502,
      );
    }
  }

  Future<void> stop(String id) async {
    final managed = _streams.remove(id);
    if (managed == null) {
      throw const GatewayRequestException(
        'Stream was not found.',
        statusCode: 404,
      );
    }
    managed.process.kill();
    managed.info = GatewayStreamInfo(
      id: id,
      state: GatewayStreamState.stopped,
      sourceCodec: managed.info.sourceCodec,
      deliveryCodec: managed.info.deliveryCodec,
      transcoded: managed.info.transcoded,
    );
  }

  Future<void> close() async {
    _reaper.cancel();
    for (final stream in _streams.values.toList(growable: false)) {
      stream.process.kill();
    }
    _streams.clear();
    _httpClient.close(force: true);
  }

  Future<String> _probeCodec(Uri source) async {
    ProcessResult result;
    try {
      result = await Process.run(config.ffprobePath, [
        '-v',
        'error',
        '-rtsp_transport',
        'tcp',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=codec_name',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        source.toString(),
      ], runInShell: false).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const GatewayRequestException(
        'Camera did not respond during the 15 second RTSP probe.',
        statusCode: 504,
      );
    }
    final codec = result.stdout.toString().trim().toLowerCase();
    if (result.exitCode != 0 || codec.isEmpty) {
      throw const GatewayRequestException(
        'Unable to inspect CCTV stream. Verify URL, credentials, and RTSP reachability.',
        statusCode: 502,
      );
    }
    return codec.split(RegExp(r'\s+')).first;
  }

  Future<void> _waitUntilReady(String id, Process process) async {
    final deadline = DateTime.now().add(config.startupTimeout);
    final playlist = Uri.parse(
      '${config.mediaMtxHlsBase.replaceFirst(RegExp(r'/+$'), '')}/$id/index.m3u8',
    );
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = await _httpClient.getUrl(playlist);
        final response = await request.close();
        await response.drain<void>();
        if (response.statusCode >= 200 && response.statusCode < 400) return;
      } catch (_) {}
      final exitCode = await _completedExitCode(process);
      if (exitCode != null) {
        throw StateError('FFmpeg stopped with exit code $exitCode.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('MediaMTX HLS playlist was not ready.');
  }

  Future<int?> _completedExitCode(Process process) async {
    try {
      return await process.exitCode.timeout(Duration.zero);
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _captureProcessExit(_ManagedStream stream) async {
    final exitCode = await stream.process.exitCode;
    if (stream.info.state == GatewayStreamState.stopped ||
        stream.info.state == GatewayStreamState.failed) {
      return;
    }
    stream.info = GatewayStreamInfo(
      id: stream.info.id,
      state: GatewayStreamState.failed,
      sourceCodec: stream.info.sourceCodec,
      deliveryCodec: stream.info.deliveryCodec,
      transcoded: stream.info.transcoded,
      message: 'FFmpeg exited unexpectedly with code $exitCode.',
    );
    _streams.remove(stream.info.id);
  }

  void _reapExpiredStreams() {
    final cutoff = DateTime.now().subtract(config.streamTtl);
    final expiredIds = _streams.entries
        .where((entry) => entry.value.createdAt.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in expiredIds) {
      final stream = _streams.remove(id);
      stream?.process.kill();
    }
  }

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(
      12,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return 'sentinvms_$suffix';
  }

  String _canonicalCodec(String codec) =>
      codec.toLowerCase() == 'h264' ? 'H264' : 'H265';
}

class _ManagedStream {
  _ManagedStream({
    required this.process,
    required this.info,
    required this.createdAt,
  });

  final Process process;
  final DateTime createdAt;
  GatewayStreamInfo info;
}
