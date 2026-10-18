import 'dart:collection';
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

  Future<void> evict() async {
    if (!_isEvicted) {
      _isEvicted = true;
      onEvicted();
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }
}

class DecoderPool {
  DecoderPool({this.maxDecoders = 4});

  final int maxDecoders;
  // O(1) LRU Double-Linked HashMap: Map key = cameraId, Value = DecoderLease
  final LinkedHashMap<String, DecoderLease> _lruMap =
      LinkedHashMap<String, DecoderLease>();

  List<DecoderLease> get activeLeases => List.unmodifiable(_lruMap.values);

  /// Acquires a lease for a video decoder with O(1) LRU eviction.
  /// If the pool is full, evicts the oldest active lease at the head of the LinkedHashMap.
  Future<DecoderLease> acquire({
    required String cameraId,
    required VideoPlayerController controller,
    required VoidCallback onEvicted,
  }) async {
    // O(1) Evict existing lease for same camera if present
    final existing = _lruMap.remove(cameraId);
    if (existing != null) await existing.evict();

    // O(1) Evict oldest lease at head if pool limit reached
    if (_lruMap.length >= maxDecoders) {
      final oldestKey = _lruMap.keys.first;
      final oldestLease = _lruMap.remove(oldestKey);
      if (oldestLease != null) await oldestLease.evict();
    }

    final lease = DecoderLease(
      cameraId: cameraId,
      controller: controller,
      onEvicted: onEvicted,
    );
    // O(1) Append to tail of LinkedHashMap (Most Recently Used)
    _lruMap[cameraId] = lease;
    return lease;
  }

  /// O(1) Releases a lease and disposes the associated controller.
  Future<void> release(DecoderLease lease) async {
    final removed = _lruMap.remove(lease.cameraId);
    await (removed ?? lease).evict();
  }

  /// Clears and disposes all active leases upon logout/session end.
  Future<void> clear() async {
    final leasesCopy = List<DecoderLease>.from(_lruMap.values);
    _lruMap.clear();
    for (final lease in leasesCopy) {
      await lease.evict();
    }
  }
}
