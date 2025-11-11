## Hotspot Onboarding (Flutter)

An interactive onboarding flow for Hotspot hosts to select experience types and answer a short question with rich media (audio/video). Built with Flutter and Riverpod, featuring polished UI, responsive layout, and robust media handling.

### Features Implemented
- AppBar and Layout
  - Centered SVG headers: `appbarline1.svg`, `appbarline2.svg`
  - Left back arrow, right close icon; background `#FFFFFF05`; wrapped in `SafeArea`
  - Keyboard-aware layout: content shifts up; no overflow flashes
- Typography and Fonts
  - Global Space Grotesk (multiple weights)
  - Adaptive title on Experience Selection: 24px → 14px on focus (single-line with ellipsis)
- Experience Selection Screen
  - Cards: 0 border radius, 130x130, 12px spacing, ±3° angles, grayscale when unselected
  - Left-aligned near the text field; responsive spacing
  - Text field: 250 characters, right-aligned counter, hint `#FFFFFF29`, focused border = primary
  - Close icon resets text, focus, and card selections
- Onboarding Question Screen
  - Same AppBar style with `appbarline2.svg`
  - Subtitle: “Tell us about your intent and what motivates you to create experiences.” (14px)
  - Text field: 600 characters, right-aligned counter, hint `#FFFFFF29`
  - Field height adapts based on audio/video presence
  - Close icon resets all page state
- Next Button (shared component)
  - 358x56, 8px radius, backdrop blur (40px)
  - Radial gradient background, linear gradient border
  - Opacity 0.3 when disabled, 1.0 when enabled
  - Text + icon vertically centered

### Audio and Video
- Audio
  - Tap to start/stop recording (toggle) via `record`
  - Live amplitude-driven waveform; live timer while recording
  - Recording box glow effect
  - After recording: “Audio Recorded • mm:ss” + small white dot
  - Left circular action toggles tick → play/pause
  - Playback with `just_audio`; waveform grey→white sweep synced to progress, right-to-left
  - Completion resets to play icon immediately (near-end tolerance)
  - Delete clears audio and UI state
- Video
  - Capture with `image_picker`, playback with `video_player`
  - Recorded tile:
    - Left: square thumbnail with play/pause overlay
    - Center: “Video Recorded • mm:ss”
    - Right: primary-colored delete icon

### Audio/Video Action Box
- Single rectangular control (112x56, 8px radius, 1px border)
- Custom `Audio.svg` and `Video.svg` with centered vertical divider
- Only the tapped icon glows; only one action (audio or video) active at a time

### Brownie Points
- Riverpod (`flutter_riverpod`) for robust, clear state management
- Smooth, real-time waveform tied to amplitude/playback progress (RTL sweep)
- Immediate UI updates for play/pause with near-end tolerance
+- Gradient borders via layered containers; BackdropFilter blur for glass effect
  - Keyboard-aware layout and transient animation suppression to avoid overflow flashes

### Additional Enhancements
- Consistent hint color `#FFFFFF29` across all text fields
- Right-aligned character counters below both fields
- Adaptive spacing and transitions for polished UX
- Defensive mic/camera permission handling
- Cleanup of unused code and lints

### Tech Stack
- Flutter, Dart
- State: `flutter_riverpod`
- Assets: `flutter_svg`
- Audio: `record`, `just_audio`
- Video: `image_picker`, `video_player`
- Permissions: `permission_handler`
- Filesystem: `path_provider`

### Getting Started
```bash
flutter pub get
flutter run
```
- iOS: `cd ios && pod install` after `pub get`.
- Ensure microphone and camera permissions are accepted.

### Project Structure
```
lib/
  src/
    state/
      onboarding_state.dart
    screens/
      experience_selection_screen.dart
      onboarding_question_screen.dart
    models/
      experience.dart
assets/
  appbarline1.svg
  appbarline2.svg
  Audio.svg
  Video.svg
  NextArrow.svg
```

### Notes
- The “Next” button enables only when there’s content (text/audio/video).
- Audio/video delete and AppBar close buttons fully reset their respective states.
- UI matches the specified palette, spacing, and typography.


