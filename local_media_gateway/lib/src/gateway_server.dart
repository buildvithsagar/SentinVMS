import 'dart:convert';
import 'dart:io';

import 'gateway_config.dart';
import 'stream_manager.dart';
import 'stream_models.dart';

class GatewayServer {
  GatewayServer({required this.config, required this.streamManager});

  final GatewayConfig config;
  final StreamManager streamManager;
  HttpServer? _server;

  Future<void> start() async {
    _server = await HttpServer.bind(config.bindAddress, config.port);
    _server!.listen(_handleRequest);
  }

  Future<void> close() async {
    await _server?.close(force: true);
    await streamManager.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _setCorsHeaders(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    try {
      _authorize(request);
      final segments = request.uri.pathSegments;
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(request.response, HttpStatus.ok, {
          'status': 'ok',
          'active_streams': streamManager.streams
              .where((stream) => stream.state == GatewayStreamState.ready)
              .length,
        });
        return;
      }

      if (segments.length == 3 &&
          segments[0] == 'api' &&
          segments[1] == 'v1' &&
          segments[2] == 'streams') {
        if (request.method == 'POST') {
          await _createStream(request);
          return;
        }
        if (request.method == 'GET') {
          final host = _publicHost(request);
          await _json(request.response, HttpStatus.ok, {
            'streams': streamManager.streams
                .map((stream) => _streamJson(stream, host))
                .toList(growable: false),
          });
          return;
        }
      }

      if (segments.length == 4 &&
          segments[0] == 'api' &&
          segments[1] == 'v1' &&
          segments[2] == 'streams') {
        final id = segments[3];
        if (request.method == 'GET') {
          final stream = streamManager.get(id);
          if (stream == null) {
            throw const GatewayRequestException(
              'Stream was not found.',
              statusCode: 404,
            );
          }
          await _json(
            request.response,
            HttpStatus.ok,
            _streamJson(stream, _publicHost(request)),
          );
          return;
        }
        if (request.method == 'DELETE') {
          await streamManager.stop(id);
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        }
      }

      throw const GatewayRequestException(
        'Route was not found.',
        statusCode: 404,
      );
    } on GatewayRequestException catch (error) {
      await _json(request.response, error.statusCode, {'error': error.message});
    } on FormatException {
      await _json(request.response, HttpStatus.badRequest, {
        'error': 'Request body must contain valid JSON.',
      });
    } catch (_) {
      await _json(request.response, HttpStatus.internalServerError, {
        'error': 'The local media gateway encountered an unexpected error.',
      });
    }
  }

  Future<void> _createStream(HttpRequest request) async {
    final contentLength = request.contentLength;
    if (contentLength > 16384) {
      throw const GatewayRequestException(
        'Request body is too large.',
        statusCode: 413,
      );
    }
    final body = await utf8.decoder.bind(request).join();
    if (body.length > 16384) {
      throw const GatewayRequestException(
        'Request body is too large.',
        statusCode: 413,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const GatewayRequestException(
        'Request body must be a JSON object.',
      );
    }
    final creation = CreateStreamRequest.fromJson(decoded);
    final stream = await streamManager.create(creation);
    await _json(
      request.response,
      HttpStatus.created,
      _streamJson(stream, _publicHost(request)),
    );
  }

  void _authorize(HttpRequest request) {
    final token = config.apiToken;
    if (token == null) return;
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        'Bearer $token') {
      throw const GatewayRequestException(
        'A valid gateway bearer token is required.',
        statusCode: 401,
      );
    }
  }

  Map<String, dynamic> _streamJson(
    GatewayStreamInfo stream,
    String publicHost,
  ) {
    final json = stream.toJson(publicHost: publicHost);
    json['whep_url'] =
        'http://$publicHost:${config.publicWebRtcPort}/${stream.id}/whep';
    json['hls_url'] =
        'http://$publicHost:${config.publicHlsPort}/${stream.id}/index.m3u8';
    return json;
  }

  String _publicHost(HttpRequest request) {
    final configured = config.advertisedHost;
    if (configured != null) return configured;
    final forwarded = request.headers.value('x-forwarded-host');
    final rawHost =
        forwarded ??
        request.headers.value(HttpHeaders.hostHeader) ??
        '127.0.0.1';
    return Uri.tryParse('http://$rawHost')?.host ?? rawHost.split(':').first;
  }

  void _setCorsHeaders(HttpResponse response) {
    response.headers
      ..set('access-control-allow-origin', '*')
      ..set('access-control-allow-methods', 'GET, POST, DELETE, OPTIONS')
      ..set('access-control-allow-headers', 'authorization, content-type');
  }

  Future<void> _json(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}
