import 'package:app/core/video/decoder_pool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

void main() {
  group('DecoderPool Tests', () {
    late DecoderPool pool;

    setUp(() {
      pool = DecoderPool();
    });

    test('Acquires leases up to maxDecoders', () async {
      final controllers = List.generate(4, (_) => MockVideoPlayerController());
      for (final controller in controllers) {
        when(controller.dispose).thenAnswer((_) => Future<void>.value());
      }

      final leases = <DecoderLease>[];
      for (var i = 0; i < 4; i++) {
        final lease = await pool.acquire(
          cameraId: 'camera_$i',
          controller: controllers[i],
          onEvicted: () {},
        );
        leases.add(lease);
      }

      expect(pool.activeLeases.length, 4);
      for (final lease in leases) {
        expect(lease.isEvicted, false);
      }
    });

    test('Acquiring 5th lease evicts the oldest lease', () async {
      final controllers = List.generate(5, (_) => MockVideoPlayerController());
      for (final controller in controllers) {
        when(controller.dispose).thenAnswer((_) => Future<void>.value());
      }

      var firstEvicted = false;
      final leases = <DecoderLease>[];

      for (var i = 0; i < 5; i++) {
        final lease = await pool.acquire(
          cameraId: 'camera_$i',
          controller: controllers[i],
          onEvicted: () {
            if (i == 0) {
              firstEvicted = true;
            }
          },
        );
        leases.add(lease);
      }

      expect(pool.activeLeases.length, 4);
      expect(firstEvicted, true);
      expect(leases[0].isEvicted, true);
      verify(controllers[0].dispose).called(1);

      for (var i = 1; i < 5; i++) {
        expect(leases[i].isEvicted, false);
      }
    });

    test('Releasing a lease removes it and disposes controller', () async {
      final controller = MockVideoPlayerController();
      when(controller.dispose).thenAnswer((_) => Future<void>.value());

      final lease = await pool.acquire(
        cameraId: 'camera_1',
        controller: controller,
        onEvicted: () {},
      );

      expect(pool.activeLeases.length, 1);
      pool.release(lease);

      expect(pool.activeLeases.length, 0);
      verify(controller.dispose).called(1);
    });

    test('clear() evicts all active leases', () async {
      final controllers = List.generate(3, (_) => MockVideoPlayerController());
      final evictions = List.filled(3, false);

      for (var i = 0; i < 3; i++) {
        final idx = i;
        when(controllers[idx].dispose).thenAnswer((_) => Future<void>.value());
        await pool.acquire(
          cameraId: 'camera_$i',
          controller: controllers[i],
          onEvicted: () {
            evictions[idx] = true;
          },
        );
      }

      expect(pool.activeLeases.length, 3);
      pool.clear();

      expect(pool.activeLeases.length, 0);
      expect(evictions, [true, true, true]);
      for (final controller in controllers) {
        verify(controller.dispose).called(1);
      }
    });
  });
}
