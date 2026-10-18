# Phase O: Native Video Evidence Export File Sharing & Evidence Saver Integration - Context

## Objectives
Enhance `ExportPage` (`features/export/presentation/pages/export_page.dart`) and `ExportRepository` (`features/export/data/export_repository.dart`) with direct Video Evidence Sharing, SHA-256 integrity verification, and Native Share Sheet triggers.

## Key Changes
- **`ExportRepository` (`lib/features/export/data/export_repository.dart`)**: Added `verifyClipIntegrity({required String jobId})` targeting `GET /recordings/exports/{jobId}/verify`.
- **`ExportPage` (`lib/features/export/presentation/pages/export_page.dart`)**: Added prominent **"SHARE EVIDENCE"** button to completed job cards and built glassmorphic `_showEvidenceShareSheet` bottom sheet modal featuring `VERIFIED INTEGRITY` badge, SHA-256 hash copy action, and native share sheet dispatcher.
- **Unit Tests (`test/unit/export_repository_test.dart`)**: Created unit test suite verifying `getExports` and `verifyClipIntegrity`.
