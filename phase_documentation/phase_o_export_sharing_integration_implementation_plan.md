# Phase O: Native Video Evidence Export File Sharing & Evidence Saver Integration - Implementation Plan

## Proposed Changes

### Data & Repository Layer
- [x] Add `verifyClipIntegrity({required String jobId})` to `ExportRepository`.

### Presentation Layer
- [x] Add **"SHARE EVIDENCE"** button to completed job cards in `_buildExportJobCard`.
- [x] Implement `_showEvidenceShareSheet` bottom sheet modal in `ExportPageState`.
- [x] Add SHA-256 hash copy and native clip sharing action triggers with electric teal feedback.

### Unit & Integration Testing
- [x] Create `test/unit/export_repository_test.dart` test suite.

## Verification Results
- Static Analysis: `flutter analyze` completed with 0 errors/warnings.
- Automated Test Suite: `flutter test` passed all 68 unit and widget tests.
