# Phase R: Enterprise Data Structures & Algorithmic Optimizations - Mermaid Architecture

```mermaid
flowchart TD
    subgraph Enterprise_DSA_Engine["Phase R DSA Optimization Engine"]
        direction TB
        subgraph DecoderPool_LRU["DecoderPool: O(1) LRU Double-Linked HashMap"]
            D1[Request Hardware Decoder Lease] --> D2{Existing in LinkedHashMap?}
            D2 -- Yes --> D3[Remove & Evict O(1)]
            D2 -- No --> D4{Size >= maxDecoders?}
            D4 -- Yes --> D5[Remove Head O(1) & Evict]
            D4 -- No --> D6[Append to Tail O(1)]
        end

        subgraph Playback_BinarySearch["PlaybackRepository: O(log N) Binary Search"]
            P1[User Scrubs Timeline] --> P2[findSegmentAtTime Target Time]
            P2 --> P3[Binary Search Mid-Point Partitioning]
            P3 --> P4[Return Matching Segment in O(log N)]
        end

        subgraph AlarmBloc_Deque["AlarmBloc: O(1) DoubleLinkedQueue Ring Buffer"]
            A1[WebSocket AI Threat Received] --> A2[DoubleLinkedQueue.addFirst O(1)]
            A2 --> A3{Queue Length > 200?}
            A3 -- Yes --> A4[removeLast O(1)]
            A3 -- No --> A5[Emit Loaded State]
        end
    end
```
