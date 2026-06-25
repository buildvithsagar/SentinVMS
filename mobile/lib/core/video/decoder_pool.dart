import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class DecoderLease {
  DecoderLease({
    required this.cameraId,
    required this.controller,
    required this.onEvicted,
  });

  final String cameraId;
  final VideoPlayerController controller;
  final VoidCallback onEvicted;
  bool _isEvicted = false;

  bool get isEvicted => _isEvicted;

  void evict() {
    if (!_isEvicted) {
      _isEvicted = true;
      onEvicted();
      try {
        controller.dispose();
      } catch (_) {}
    }
  }
}

class DecoderPool {
  DecoderPool({this.maxDecoders = 4});

  final int maxDecoders;
  final List<DecoderLease> _leases = [];

  List<DecoderLease> get activeLeases => List.unmodifiable(_leases);

  /// Acquires a lease for a video decoder.
  /// If the pool is full, evicts the oldest active lease.
  Future<DecoderLease> acquire({
    required String cameraId,
    required VideoPlayerController controller,
    required VoidCallback onEvicted,
  }) async {
    // Evict if limit reached
    if (_leases.length >= maxDecoders) {
      _leases.removeAt(0).evict();
    }

    final lease = DecoderLease(
      cameraId: cameraId,
      controller: controller,
      onEvicted: onEvicted,
    );
    _leases.add(lease);
    return lease;
  }

  /// Releases a lease and disposes the associated controller.
  void release(DecoderLease lease) {
    if (_leases.remove(lease)) {
      try {
        lease.controller.dispose();
      } catch (_) {}
    }
  }

  /// Clears and disposes all active leases.
  void clear() {
    final leasesCopy = List<DecoderLease>.from(_leases);
    _leases.clear();
    for (final lease in leasesCopy) {
      lease.evict();
    }
  }
}
