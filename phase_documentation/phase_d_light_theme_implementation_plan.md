# Implementation Plan — Premium Modern Light-Theme Redesign & Real Integration (Phase D.6)

This plan details the visual overhaul of the VMS mobile client to a light theme and the removal of all mock data in favor of real API repository bindings.

---

## 1. Visual Theme Updates

We establish a clean, modern enterprise design:
*   **Backgrounds:** Scaffold backgrounds shifted to soft blue-grey (`0xFFF4F7FC`).
*   **Surfaces:** Cards and inputs shifted to pure white (`0xFFFFFFFF`) with soft drop shadows and thin borders (`0xFFCBD5E1`).
*   **Text:** Primary text using slate charcoal (`0xFF1E293B`) and labels using grey (`0xFF64748B`).
*   **Accent Color:** Solid brand blue (`0xFF2563EB`) replaces tactical green.
*   **Playback Scrubber:** Shifted to a light-grey track with pastel color-coded continuous, motion, and scheduled segments.

---

## 2. API Integration & Mock Removal

*   **Playback Screen:** Refactored to fetch the list of real cameras from `CameraRepository`. On selecting a camera, it fetches real recording segments from `PlaybackRepository` for the selected date. When seeking, it fetches a real playback HLS URL from the backend and streams it via `VideoPlayerController`.
*   **Export Screen:** Refactored the manual text entry to a clean camera dropdown picker using real cameras. Refactored the export history list to retrieve actual export jobs from `ExportRepository`. Implemented creation of real exports on submission and a status polling loop for processing jobs.
*   **Login Screen:** Corrected text contrast for typed values to deep slate charcoal so they are readable on white inputs.
