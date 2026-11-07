# Mobile motion

The opening sequence, activity indicators, wishlist feedback, navigation pill,
and order confirmation use Flutter animations and canvas drawing. This refinement
adds no animation assets or dependencies. The opening uses the existing logo. See `opening_preview.md` for the extended skippable tour and its verification limits.

## Timing

| Interaction | Duration |
| --- | --- |
| Small status changes | 160 ms in, 120 ms out |
| Navigation selection | 240 ms |
| Successful wishlist selection | 360 ms |
| Order confirmation stroke | 520 ms |
| Opening logo phase | 620 ms |
| Skippable shopping/delivery tour including logo | 15.2 s (16 s deadline) |

## Rendering and lifecycle

- `motion_preferences.dart` holds common timing and the reduced-motion policy.
- `motion_timeline.dart` owns finite and repeating clocks. Hidden routes and
  backgrounded apps stop these clocks; resuming continues playback. Finite
  effects stop on completion. Reduced motion shows the final state immediately.
- `motion_effects.dart` paints small activity rings, progress lines, and the
  confirmation mark. Painter repaint listeners update these surfaces without
  rebuilding the surrounding page. Repaint boundaries isolate that work.
- Skeleton cards stay static. There is no animation controller per placeholder,
  full-screen shimmer, animated blur, or particle system.
- Navigation moves its selection pill with a paint transform. Its nearly opaque
  surface disables the existing backdrop blur, reducing work during scrolling.
- A wishlist effect runs for a new successful selection, never simply because a
  saved product appears in a list. It settles after one restrained overshoot.
- Existing image cache and decode-size limits remain in use.

## Checks

`test/motion_lifecycle_test.dart` checks hidden/background pause and resume,
reduced motion during playback, lack of surrounding widget rebuilds during clock
ticks, successful wishlist feedback, disposal, and finite confirmation playback.
The existing motion, cart, rider, route-retention, and buyer-flow tests cover the
integration behavior. Light and dark previews can be rendered from widgets.

For an ARM64 size check, use a release build rather than the universal debug APK:

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-pub
```

This command retains the project's default API and signing configuration. APK
download size differs from installed storage, which also includes extracted
libraries, app data, and image caches. Actual frame times still need profiling on
representative phones; widget checks alone do not establish a frame-rate claim.
