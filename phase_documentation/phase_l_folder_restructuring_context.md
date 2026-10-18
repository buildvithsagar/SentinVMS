# Phase L: Enterprise Architecture & Feature-First Folder Restructuring - Context

## Objectives
Reorganize SentinVMS mobile codebase (`mobile/lib`) into a standardized, production-grade Feature-First Clean Architecture pattern. Eliminate inconsistent file placements, separate presentation pages from root feature folders, and add centralized barrel exports (`index.dart` / feature exports) across all modules.

## Restructured Features & Core
- **`core/`**: Centralized core barrel export (`core.dart`).
- **`features/login/`**: `data/`, `bloc/`, `presentation/pages/login_page.dart`, `login.dart`.
- **`features/live_view/`**: `presentation/pages/live_grid_page.dart`, `presentation/widgets/video_tile.dart`, `live_view.dart`.
- **`features/camera/`**: `data/`, `bloc/`, `models/`, `presentation/pages/camera_list_page.dart`, `camera.dart`.
- **`features/alarms/`**: `data/`, `bloc/`, `models/`, `presentation/pages/alarm_list_page.dart`, `alarms.dart`.
- **`features/playback/`**: `data/`, `models/`, `presentation/pages/playback_page.dart`, `playback.dart`.
- **`features/export/`**: `data/`, `models/`, `presentation/pages/export_page.dart`, `export.dart`.
- **`features/device_onboarding/`**: `data/`, `bloc/`, `presentation/pages/` (`device_category_page.dart`, `device_details_form_page.dart`), `presentation/widgets/`, `device_onboarding.dart`.
