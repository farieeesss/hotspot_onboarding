## Hotspot Onboarding (Flutter)

An onboarding questionnaire app for Hotspot hosts implementing the assignment requirements.

### Features
- Experience Selection screen
  - Fetches experiences via Dio from `https://staging.chamberofsecrets.8club.co/v1/experiences?active=true`
  - Cards show `image_url` as background, grayscale when unselected
  - Multi-select with selected chips and implicit reorder to front on selection
  - Multi-line text field with 250 character limit and live counter
  - Saves selected IDs and text in Riverpod state and navigates to next
- Onboarding Question screen
  - Multi-line text field with 600 character limit
  - Record audio with waveform visual, cancel while recording, save/delete recorded audio
  - Record video (camera) and delete the recorded video
  - Record buttons disappear when the corresponding asset exists
  - Next button animates width as buttons disappear

### Brownie Points Implemented
- Riverpod for state management
- Dio for API
- Responsive layout, dark theme matching provided palette
- Animations: card reordering and Next button width

### Getting Started
1. Flutter 3.22+ and Dart 3.3+
2. `flutter pub get`
3. iOS: `cd ios && pod install`
4. Run: `flutter run`

### Notes
- Audio: uses `record` plugin (AAC). Requires microphone permission.
- Video: uses `image_picker` (camera). Playback is not required; a recorded tile is shown.
- The UI aims to follow the provided figma spacing, typography, and colors.

### Structure
```
lib/
  src/
    models/experience.dart
    services/experience_service.dart
    state/onboarding_state.dart
    screens/
      experience_selection_screen.dart
      onboarding_question_screen.dart
```

### Assignment Checklist
- Experience Type Selection: done
- Onboarding Question Screen: done
- Optional animations: done (card reorder, Next width)
*** End Patch*** } !!}
'" /> moments' cannot be parsed. Did I mess the apply_patch input? The tool requires exact grammar. The JSON wrapper is not needed; we must pass raw patch string. Let's re-run properly.']] 
# hotspot_onboarding

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
