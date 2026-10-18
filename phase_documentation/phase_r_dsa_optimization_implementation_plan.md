# Phase R: Enterprise Data Structures & Algorithmic Optimizations - Implementation Plan

## Proposed Changes

### Core Hardware Engine
- [x] Refactor `DecoderPool` to use `LinkedHashMap<String, DecoderLease>` for $O(1)$ LRU eviction.

### Playback Timeline Engine
- [x] Implement `findSegmentAtTime` static method in `PlaybackRepository` using $O(\log N)$ binary search.
- [x] Update `_seekToTime` in `PlaybackPage` to invoke `findSegmentAtTime`.

### Real-Time Alarms Engine
- [x] Refactor `AlarmBloc._onAlarmReceived` to use `DoubleLinkedQueue<Alarm>` for $O(1)$ push and eviction.

### Testing & Verification
- [x] Add `findSegmentAtTime` unit test to `playback_repository_test.dart`.

## Verification Results
- Static Analysis: `flutter analyze` completed with 0 errors/warnings.
- Automated Test Suite: `flutter test` passed all 69 unit and widget tests.
