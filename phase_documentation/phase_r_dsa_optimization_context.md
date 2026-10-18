# Phase R: Enterprise Data Structures & Algorithmic Optimizations - Context

## Objectives
Enforce optimal Data Structures and Algorithms (DSA) across all core modules in SentinVMS to guarantee $O(1)$ time complexity for hardware decoder lease promotion/eviction and real-time alert buffer management, and $O(\log N)$ time complexity for 24-hour timeline recording segment lookup:
1. **$O(1)$ LRU Double-Linked HashMap Cache (`DecoderPool`)**: Upgraded `DecoderPool` to use `LinkedHashMap<String, DecoderLease>` for $O(1)$ constant time lease acquisition, promotion, and head eviction.
2. **$O(\log N)$ Binary Search Segment Lookup (`PlaybackRepository`)**: Created static `findSegmentAtTime(List<RecordingSegment> segments, DateTime targetTime)` using binary search lower bound.
3. **$O(1)$ Circular Ring Buffer / Deque (`AlarmBloc`)**: Upgraded `AlarmBloc` real-time threat ingestion to use `DoubleLinkedQueue<Alarm>` for $O(1)$ push to front (`addFirst`) and $O(1)$ eviction (`removeLast`).
4. **Active Playback Segment Badge**: Displayed `_activeSegment` type badge in `PlaybackPage` top toolbar overlay.

## Key Changes
- **`DecoderPool` (`lib/core/video/decoder_pool.dart`)**: Replaced `List<DecoderLease>` with `LinkedHashMap<String, DecoderLease>`.
- **`PlaybackRepository` (`lib/features/playback/data/playback_repository.dart`)**: Added `findSegmentAtTime` static binary search method.
- **`PlaybackPage` (`lib/features/playback/presentation/pages/playback_page.dart`)**: Integrated `PlaybackRepository.findSegmentAtTime` in `_seekToTime`.
- **`AlarmBloc` (`lib/features/alarms/bloc/alarm_bloc.dart`)**: Replaced array slicing with `DoubleLinkedQueue` deque ring buffer.
- **Unit Tests (`test/unit/playback_repository_test.dart`)**: Added unit test for `findSegmentAtTime`.
