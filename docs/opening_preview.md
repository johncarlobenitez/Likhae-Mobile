# Opening preview

The startup route runs the existing session restoration once, concurrently with
an optional 7.6-second tour. Skip and reduced motion finish the tour immediately;
an independent eight-second deadline also ends it if ticking stops. Authentication
and policy/role selection remain authoritative. `context.go` removes startup,
and errors retain the existing retry UI. No launch-history storage was added.

The logo phase retains the existing 620 ms reveal. The following phases mount
only one real production screen at a time: buyer Home/Discover (including a scroll
through categories and product cards), Wishlist, Cart, OrderSuccess,
OrderTracking, then the closing brand screen. Short fade/scale wrappers animate
the screen; there is no per-frame page setState. The phone preview has a 430 x 900
layout fitted to available space; its controls are read-only, with Skip outside.

Home's explicit `localPreview` mode bypasses wishlist loading and mutation,
catalog loading, the service-backed navigation host, and AI assistant. The tour
uses the same GlassNavigationFrame/GlassNavigationBar presentation. Cart and
Wishlist receive local data and no service callbacks. Tracking uses its existing
`isPreview` state and substitutes only the map surface, so no native map, tile
fetching, realtime subscription or location polling starts.

The two product photos are 480-pixel copies of the exact demo-catalog images
already referenced by ProductService (vase and headphones), bundled under
assets/opening (38,804 bytes total). They use the existing product image/card
layout through SizedNetworkImage's local-asset branch. No startup downloads or
new packages. Their source URLs are:

- https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=480&q=75
- https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=480&q=75

The logo is precached once with the same 288-pixel ResizeImage key used to render
it. Asset failures use a local icon and do not gate navigation. The brand painter
caches its outline, metrics and stroke. The old indefinitely spinning startup
indicator is now static. The tour controller, deadline and scroll controller are
disposed; after completion while authentication is pending only static text remains.

No reference video was supplied. Performance-conscious choices are short
fade/scale transitions, a static map surface, two small local photos, and a
single visible screen instead of stacked offstage production screens. Normal
Laravel and Reverb implementations are unchanged.

## Verification

`test/opening_animation_test.dart` traverses all production preview screens,
rejects network-client creation, verifies wishlist state is unchanged, and checks
completion, Skip, reduced motion, early disposal and absence of scheduled tickers.
Existing buyer performance, motion and rider scan tests also cover normal flows.

Actual 60 Hz/120 Hz frame timing, memory and post-intro scrolling must still be
measured on representative Android hardware. No Android device is attached here.
`flutter run --profile -d windows --no-pub` fails because the Visual Studio C++
toolchain is unavailable; no runtime FPS or no-regression claim is established.
On a connected phone run `flutter run --profile -d <device-id>`, record DevTools
frame/memory traces for the intro, then product scroll, wishlist/cart, navigation,
tracking, messages and rider workflow. Compare identical baseline/post-change
runs; verify no intro tickers or timers remain after Skip/completion/navigation.

Validation results for this implementation: full suite 58 passed / 57 skipped;
the final focused tour suite passes all four tests, including the independent
background deadline. `flutter analyze --no-pub` reports 87 existing warnings/info
findings and no errors (same count as the initial baseline). Test-rendered phase
captures were visually reviewed; they are not device performance measurements.

Follow-up: all 57 previously skipped API tests were run separately with
`flutter test --no-pub --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://127.0.0.1:18764/api/v1 test/api_request_loading_test.dart test/rider_api_contract_test.dart`.
All 57 passed. These tests use local HTTP fixtures, not the live Laravel server.
