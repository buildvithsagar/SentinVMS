# Phase P: ONVIF Subnet Packet Scanner & Dynamic Device Discovery Integration - Context

## Objectives
Enhance `DeviceOnboardingRepository` (`features/device_onboarding/data/device_onboarding_repository.dart`) and `DeviceCategoryPage` (`features/device_onboarding/presentation/pages/device_category_page.dart`) with real UDP WS-Discovery Subnet Packet Scanning. Enable real-time discovery of LAN CCTV cameras (Hikvision, Dahua, Axis, CP PLUS) on Port 3702, displaying IP address, ONVIF Profile (S/T/G), hardware spec tags, and latency indicators.

## Key Changes
- **`DeviceOnboardingRepository` (`lib/features/device_onboarding/data/device_onboarding_repository.dart`)**: Created `DiscoveredOnvifDevice` model and `scanSubnetForOnvifDevices()` method targeting UDP WS-Discovery broadcast port 3702.
- **`DeviceCategoryPage` (`lib/features/device_onboarding/presentation/pages/device_category_page.dart`)**: Connected ONVIF category card tap to live subnet scan dialog (`Probing Local Subnet (UDP 3702)...`) and built `_showDiscoveredDevicesModal` rendering real-time discovered cameras, signal latency badges (`<12ms`), ONVIF profile badges, and direct device registration actions.
- **Unit Tests (`test/unit/device_onboarding_repository_test.dart`)**: Created unit test suite verifying `scanSubnetForOnvifDevices` discovery output and `onboardDevice` completion.
