# Rider API synchronization — 2026-10-30

Implemented against `C:/Users/Administrator/Downloads/Likhae-working (13).zip`, using its real controllers, models, authorization rules and services. The source ZIP and deployed server were not modified. Laravel changes are in `laravel_checkout_upload/` and the rebuilt `laravel_checkout_upload.zip`.

## Behavior

- Both delivery forms require a matching parcel scan or manual tracking code, receiver name, proof photo and actual collected amount. Completion posts the proof with `_method=PATCH`, `action=delivery_success`, `scanned_code`, `scan_method`, `receiver_name` and `collected_amount` to the existing assignment endpoint. Laravel retains authoritative ownership, tracking-code and state validation.
- Pickup lists continue to use seller batches. Older individual-parcel links resolve their owned batch through `GET rider/pickups/{assignment}/batch`; all resulting actions use existing batch services. The legacy client helper also resolves its batch before acting. The generic rider scanner now looks up current API assignments and opens the matching delivery or pickup batch.
- Pickup batches left `EN_ROUTE_TO_HUB` by an older server version are reconciled when logistics receives a parcel and when the owning rider reloads batch details. Later shipment statuses prove center intake already occurred; the batch completes after every collected parcel is received and every other assignment is resolved.
- API presence uses the same controller/cache as the website, with privacy preferences, authentication, rate limiting and expiry. Both rider and buyer conversation responses expose actual presence. The existing buyer mobile presence path is also registered.
- Earnings now opens Cash remittances. The form loads eligible COD collections and paginated history, submits exactly one collection plus the actual handoff amount and notes, and reloads after server confirmation. Duplicate taps are disabled. A confirmed receipt remains visible if refresh fails. Logistics acknowledgment stays in the existing logistics website workflow.
- Earnings shares that have not been allocated remain null and display as awaiting allocation. Rider earnings are not automatically marked paid when delivery or remittance completes; existing allocation/approval/payout decisions determine that state.

## Laravel upload files relevant to this fix

- `routes/api.php`
- `app/Http/Controllers/Api/RiderApiController.php`
- `app/Http/Controllers/Api/RiderPickupBatchApiController.php`
- `app/Http/Controllers/Api/BuyerApiController.php`
- `app/Http/Controllers/Communication/MessagePresenceController.php`
- `tests/Feature/MobileRiderSyncTest.php` (optional test deployment)

The package also retains previous logistics, auth, availability, profile, transfer, checkout and map updates. Its `UPLOAD_INSTRUCTIONS.txt` lists every runtime file. No new migration is introduced. Existing full-project finance/pickup schemas and services are required.

## Validation

Final results: 70 focused Flutter tests passed; 9 Laravel feature tests passed with 108 assertions; all 15 PHP files in the package passed syntax checks. Focused Flutter analysis found no errors or warnings, with 14 existing informational diagnostics in the router. `git diff --check` reported no whitespace errors.

Flutter HTTP contract tests run against a loopback fixture server. They cover authentication, endpoint selection, multipart delivery scan/proof/amount fields, rejected or missing scans, owned batch resolution before writes, remittance pagination and decimal serialization, failed submissions, and unallocated earnings. Widget tests cover manual scan matching, pickup workflow and refresh failures, and remittance duplicate-submit protection and confirmed receipts surviving refresh failures.

Laravel tests run against a separate extracted copy of the full project with the upload files applied and SQLite `:memory:`. The new tests exercise real API authentication, presence privacy and shared cache, pickup ownership and accept/start/scan/finish transitions, valid/invalid delivery scans, COD persistence, remittance submission and repeat handling. The existing rider API tests are also run. No live account or shipment was used.

Commands:

```powershell
flutter test --no-pub --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://127.0.0.1:18764/api/v1 test/rider_api_contract_test.dart test/rider_delivery_scan_field_test.dart test/rider_remittances_screen_test.dart test/rider_pickup_sync_test.dart test/rider_api_loader_test.dart test/rider_messages_screen_test.dart
flutter analyze --no-pub --no-fatal-infos lib/services/rider_mobile_service.dart lib/features/rider/deliveries lib/features/rider/earnings lib/routes/app_router.dart
```

The temporary Laravel test config replaces the archive's MySQL test settings with SQLite `:memory:`. Never run database-refresh tests against production.

```powershell
php vendor/phpunit/phpunit/phpunit -c phpunit.rider-sync.xml --filter 'MobileRiderSyncTest|RiderMobileApiTest'
```

## Deployment and remaining device verification

Copy the package to the matching paths of the full Laravel project and clear its route cache. Rebuild and reinstall Flutter with `API_ENABLED=true` and `API_BASE_URL` pointing to the same server's `/api/v1`. API access defaults to disabled in this repository.

Use staging parcels for the actual camera, proof capture/upload, GPS, and logistics acknowledgment flow. Automated source/fixture/database checks do not verify the currently deployed host, existing installed APK, network configuration, or physical devices.
