# Phase J Implementation Plan — Device Onboarding UI Redesign

## Goal Description
Redesign the **Device Onboarding Module** (`Select Device Category`, `Onboarding Mode Sheet`, and `Device Details Form`) to elevate the user interface from flat basic cards to a premium, interactive **Subtle Dark Glassmorphism** design system matching Apple/Verkada security console aesthetics.

## Proposed Changes

### Device Onboarding Feature

#### [MODIFY] [device_category_page.dart](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile/lib/features/device_onboarding/presentation/device_category_page.dart)
- Upgrade theme to **Subtle Dark Glassmorphism** (Dark Slate `#0F172A` canvas, `BackdropFilter` glass cards with `sigmaX: 10, sigmaY: 10`, Electric Teal `#2DD4BF` active accents).
- Transform flat static category tiles into interactive glass cards featuring:
  - Scale & elevation animations on press/tap (`AnimatedScale` & `AnimatedContainer`).
  - Glowing electric teal avatar icon containers (`48x48` rounded container with low-opacity `#2DD4BF`).
  - Detailed category subtitles (e.g. "Wi-Fi, Battery & Solar IP Cameras", "PoE & Direct Ethernet Cameras").
  - Technical hardware badges (e.g. `Wi-Fi 6`, `PoE / ONVIF`, `4K Speed Dome`, `RAID NVR`, `Edge AI`).
- Add an interactive **Search & Filter bar** at the top to filter categories dynamically.
- Add an enterprise header banner ("5 Hardware Categories • Auto-Discovery Ready").

#### [MODIFY] [onboarding_mode_sheet.dart](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile/lib/features/device_onboarding/presentation/widgets/onboarding_mode_sheet.dart)
- Upgrade bottom sheet modal with glassmorphism styling (`BackdropFilter`, rounded top corners `24px`, teal grab handle).
- Enhance mode option tiles with glowing icon avatars, clear titles, descriptive action subtitles, and smooth hover/press animations.

#### [MODIFY] [device_details_form_page.dart](file:///c:/Users/SAGAR/vmsapp/SentinVMS/mobile/lib/features/device_onboarding/presentation/device_details_form_page.dart)
- Align form inputs with glassmorphic text containers, electric teal focus outlines (`#2DD4BF`), and glass card groupings.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure zero linter or syntax errors.
- Run `flutter test` to ensure all existing widget and unit tests continue passing.

### Manual Verification
- Test interactive category cards (tap press feedback, scale animations, search filter).
- Verify bottom sheet modal opening and navigating to scan / manual registration forms.
