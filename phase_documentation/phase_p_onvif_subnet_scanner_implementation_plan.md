# Phase P: ONVIF Subnet Packet Scanner & Dynamic Device Discovery Integration - Implementation Plan

## Proposed Changes

### Data & Repository Layer
- [x] Create `DiscoveredOnvifDevice` model in `device_onboarding_repository.dart`.
- [x] Add `scanSubnetForOnvifDevices()` method to `DeviceOnboardingRepository`.

### Presentation Layer
- [x] Connect ONVIF category card taps in `DeviceCategoryPage` to `_runSubnetOnvifScan`.
- [x] Build `_showDiscoveredDevicesModal` displaying discovered cameras, signal latency badges (`<12ms`), ONVIF profile badges, and direct registration triggers.

### Unit & Integration Testing
- [x] Create `test/unit/device_onboarding_repository_test.dart` test suite.

## Verification Results
- Static Analysis: `flutter analyze` completed with 0 errors/warnings.
- Automated Test Suite: `flutter test` passed all 70 unit and widget tests.
