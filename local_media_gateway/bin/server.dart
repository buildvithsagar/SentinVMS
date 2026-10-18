import 'dart:async';
import 'dart:io';

import 'package:sentinvms_local_media_gateway/local_media_gateway.dart';

Future<void> main() async {
  final config = GatewayConfig.fromEnvironment(Platform.environment);
  final manager = StreamManager(config: config);
  final gateway = GatewayServer(config: config, streamManager: manager);

  await gateway.start();
  stdout.writeln(
    'SentinVMS local media gateway listening on '
    'http://${config.bindAddress.address}:${config.port}',
  );

  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('Received $signal. Stopping streams...');
    await gateway.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}
