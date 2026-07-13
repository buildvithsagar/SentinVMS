# Phase G Implementation Plan - VMS UX Redefinition & New Features

## Step 1: Login & Navigation
- Remove the bottom "Back to login" text button on the OTP view.
- Inject a leading standard BackButton on the page AppBar when `_showOtpView` is true.

## Step 2: Live View Dashboard
- Construct a standard Navigation Drawer on LiveGridPage containing logo, profile info, and a secure Logout button.
- Relocate Logout button from AppBar actions.
- Wrap Clear All action with an AlertDialog confirmation.
- Add HD/SD Quality toggle SnackBar notification.
- Add Instant Playback (replay 30s) and Snapshot capture buttons in tile control row.
- Add floating red Panic FAB with emergency sirens, calls, and audio broadcast dialog triggers.

## Step 3: Playback Screen
- Remove the bottom PlaybackSpeedControl chip row.
- Wrap video player with Stack overlay toolbar.
- Place Snapshot button and Speed dropdown menu at the top.
- Place 10s Rewind, Play/Pause, and 10s Forward icon buttons in the center of the player overlay.
- Hook haptic feedback inside TimelineScrubber drag handler when crossing recording blocks.

## Step 4: Alarms screen
- Remove card ACK buttons.
- Configure card tap to open detailed modal bottom sheet containing snapshot placeholder frame, time metadata, and ACK button.
