# LIKHAE Mobile

## Laravel API

The app uses the Laravel API at `https://likhae.online/api/v1` by default.
API access remains disabled unless enabled at build/run time, so development
continues to use the existing offline/demo behavior by default.

Run with the API enabled:

```sh
flutter run --dart-define=API_ENABLED=true
```

Run with Laravel Reverb enabled in PowerShell. Set the Reverb app key in the
same PowerShell window first, then run the command:

```powershell
$env:REVERB_APP_KEY = 'your-reverb-key'
```

```powershell
flutter run --dart-define="API_ENABLED=true" --dart-define="REVERB_APP_KEY=$($env:REVERB_APP_KEY)" --dart-define="REVERB_HOST=likhae.online" --dart-define="REVERB_PORT=443" --dart-define="REVERB_SCHEME=https"
```

Override the API and web origins for a local or staging backend:

```sh
flutter run --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=https://your-host.example/api/v1 --dart-define=WEB_BASE_URL=https://your-host.example
```

The API client sends the stored mobile login token as a Bearer token. Only
buyer and rider features listed below are synchronized when API mode is
enabled. Other app areas still depend on their existing local/demo behavior.

### Buyer API coverage

With `API_ENABLED=true`, buyer catalog/product details, cart, checkout (including
per-shop notes saved with each seller order) and seller vouchers, order
history/actions/reviews/returns, address create/delete/
default selection, wishlist, rewards, notifications, seller conversations and
image attachments, and profile name/contact/birthday/gender/photo and password
changes use authenticated Laravel APIs. Messages and notifications use
targeted Reverb subscriptions when configured, with API polling as fallback.
Buyer and rider notifications stay subscribed across their app screens and show
as a dismissible banner at the top while the app is open. If Reverb is not
configured or cannot connect, the foreground banner checks the notification
API every 15 seconds. This in-app banner does not deliver operating-system
push notifications while the app is closed.
Buyer notification category switches are saved on the device and control which
order, delivery, chat, and reward banners appear while the app is open. Delivery
updates have their own notification type and inbox filter. The notification and
AI response sound switches play a platform alert sound when those events arrive.
Wishlist records and profile photos require applying the new Laravel migration.

Email changes remain unavailable: they need a verified email-change flow, not
an unverified profile update. Address entry matches names against active
delivery-service-area data when possible; checkout rejects addresses without
an active service area. Add the correct service-area/PSGC records in Laravel
before expecting delivery outside the configured coverage. Cashback remains
zero because the current Laravel rewards rules do not implement cashback.

### Rider API coverage

With `API_ENABLED=true`, rider dashboard summaries, active pickup and delivery
assignments, pickup tracking-code verification, delivery history, recorded
earnings, profile details, and rider conversations use authenticated Laravel
endpoints. Rider status changes call the existing assignment workflow:
assignments must be accepted and started before completion, pickup completion
records the scanned waybill, and delivery completion uploads its proof photo
and receiver name. Earnings show the amounts already recorded by the Laravel
workflow; payout rules and settlement remain controlled by the backend.
Messages use a targeted Reverb conversation subscription when configured, with
polling as fallback. While an active delivery is being tracked, the rider app sends
throttled GPS updates to Laravel. Laravel stores only the latest position for
that delivery assignment and makes it available in the authenticated buyer
order response while the shipment remains out for delivery. The position is
deleted when the assignment leaves its active delivery state; no location
history is retained.

The rider APIs use the existing rider, shipment, assignment, earning, and
messaging tables, plus a latest-location table for active delivery assignments.
Apply pending project migrations and publish public storage before testing
delivery proof uploads or live location updates.

Before running against the modified Laravel project, apply its migration and
publish the public storage link:

```sh
php artisan migrate
php artisan storage:link
```

For a local XAMPP backend, `API_BASE_URL` must be reachable from the device and
end in `/api/v1`; `WEB_BASE_URL` must be the corresponding web root used for
product images. Android Emulator usually reaches the Windows host through
`10.0.2.2`; a physical device must use the computer's LAN IP. The Laravel
project must be served by Apache and its API routes must be reachable before
enabling API mode.
