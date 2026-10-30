# Rider/mobile synchronization check

Historical check: the backend gaps described below have now been addressed against the full Laravel ZIP. See [the current synchronization report](rider_api_sync_2026_10_30.md) for the implementation and latest checks.

Date: 2026-10-30. Compared the Flutter project with `laravel_checkout_upload`.

## Result

Mobile fixes are implemented and automated tests pass. This is **not a claim that every function works against the deployed Laravel server**. The upload is a partial backend, and no Android/iOS device is connected. The HTTP tests run against a local fixture server, not Laravel.

## Changes implemented

- Pickup batch scanning and manual tracking entry are at the top of the page. They remain visible before pickup starts, with an explanation of when they become available.
- Single pickup scan controls appear before pickup actions. Accept and start are still required before verification; completion requires a verified code.
- QR and barcode results retain their actual input method. Single pickup completion submits the entered/scanned value rather than substituting the expected tracking number from the assignment.
- Inter-hub transfers now have a camera button for each parcel, plus manual entry. The latest manifest is loaded before opening the scan form. Every parcel requires a code before transport can start. Laravel accepts one scan method per manifest; mixed camera/manual input is submitted as MANUAL.
- Batch details reload on entry and after an action. An explicit refresh button retries failed reads. If a write succeeds but its reload fails, further actions are blocked until a successful refresh, preventing accidental replay using stale status.
- Delivery rejection now passes client validation and sends `action=reject` with its reason. Failure aliases and normalized status values match service action mapping. Delivery success still requires receiver name and proof.
- Rider and logistics services reject `success:false` even if HTTP status is 200. Logistics receiving requires the returned tracking number and shipment status instead of inventing a successful receipt when those fields are missing.
- Dialog text controllers remain alive through closing animations. iOS camera permission text now describes barcode/QR scanning as well as delivery proof.

## Pickup process

### Batch pickup

1. Open the batch; load its current details from Laravel.
2. LOADING: accept the batch.
3. READY: start seller pickup.
4. IN_PROGRESS: scan a QR/barcode or enter its tracking code. The mobile requires the scan response to confirm `shipment_status=PICKED_UP` and reloads the batch.
5. For a parcel that cannot be collected, submit its assignment ID and a reason.
6. Finish becomes available only when every item is resolved. The mobile recognizes assignment statuses COMPLETED, REJECTED, and CANCELLED as resolved; only COMPLETED counts as collected.
7. After Laravel reports EN_ROUTE_TO_HUB, take the collected parcels to the hub. Logistics scans receipt through `/logistics/scan-receive`. Its backend workflow determines the next shipment status.

The actual accept/start/scan/finish mutation controllers and workflow service are not included in the upload, so their database transitions still need verification.

### Single pickup

Accept → start seller pickup → scan or enter tracking → verify with Laravel → confirm picked up → deliver to logistics for receipt. Editing an already verified code invalidates verification.

## Function coverage

“Pass” below means the specified automated mobile test passed; it does not mean deployment or device acceptance passed.

| Function | Automated result | Remaining verification |
|---|---|---|
| Dashboard, assignments, pickups, history, earnings, profile reads | Pass: parsing, endpoint selection, bearer token | Real account data and permissions |
| Assignment/pickup pagination | Pass: subsequent pages requested and combined | Real pagination payloads |
| Batch accept/start/manual scan/not-collected/finish | Pass: widget sequence and HTTP requests | Laravel database transitions |
| Scan response confirmation | Pass: PICKED_UP is accepted and unknown statuses are rejected | Add regression coverage for later statuses such as DELIVERED; physical QR/barcode decoding |
| Batch refresh/retry and rejected scans | Pass: stale actions blocked; failed scans remain unresolved | Network interruptions on device |
| Single pickup accept/start/verify/complete | Pass: UI sequence, wrong-code rejection, verification reset, actual code submission | Live server verification and camera |
| Transfer list/details/accept/decline/start | Pass: HTTP requests, item scan map and methods | Real transfer workflow |
| Transfer camera controls | Pass: injected scan results populate both parcel inputs; missing codes block start | Camera hardware and permissions |
| Transfer stale manifest protection | Pass: transport blocked when refreshed manifest cannot start | Concurrent logistics release/cancellation |
| Delivery accept/start/reject/failure | Pass: action mapping and required reasons | Server assignment rules |
| Delivery success | Pass: required proof/receiver; multipart file and PATCH override | Actual image capture, upload storage, server processing |
| Online/offline availability and dispatch location | Pass: HTTP fields and returned availability validation | GPS permission/device readings, dispatch selection |
| Active delivery location | Pass: coordinates, accuracy, UTC timestamp | Device tracking lifecycle and buyer map |
| Vehicle plate and residential address | Pass: mobile request/response handling | Missing controller implementation in upload |
| Notifications/read-all | Pass: HTTP handling | Live notification delivery |
| Conversations/read/send | Pass: HTTP handling; existing messaging widget tests pass | Live Reverb subscription and polling recovery |
| Profile edit/photo/password | Pass: client serialization only | **Routes absent from supplied Laravel routes** |
| Message presence helper | Pass: client serialization only | **Route absent; helper not wired into current rider route** |
| Logistics dashboard and parcel receipt | Pass: parsing, three scan methods, missing confirmation and rejected receipt handling | Actual receipt after rider pickup |
| HTTP 401/403/404/422/500 and malformed payloads | Pass: errors surface rather than being treated as success | Server-specific responses |

## Backend gaps to resolve

The supplied route file has no `PATCH /api/v1/rider/profile` or `PATCH /api/v1/rider/profile/password`, although the mobile edit screen calls them. Photo updates use POST with `_method=PATCH` to the same profile endpoint. The unused presence helper targets `POST /api/v1/messages/presence`, also absent.

The upload references but does not include `RiderApiController`, `RiderPickupBatchController`, `WorkflowApiController`, and `RiderVehicleProfileController`, plus their models/services. Adding speculative route handlers would not establish correct ownership, authorization, validation, or persistence. The complete updated backend is needed to implement and test these gaps.

Other Laravel copies exist on this computer. The `C:/xampp/htdocs/Likhae-working` rider controller lacks the batch actions referenced by this upload, so it was not assumed to be the current backend and was not modified.

## Test commands and results

```powershell
flutter test --no-pub
flutter test --no-pub --dart-define=API_ENABLED=true --dart-define=API_BASE_URL=http://127.0.0.1:18764/api/v1 test/rider_api_contract_test.dart test/api_request_loading_test.dart
```

The default suite intentionally skips API-enabled cases. The second command runs those cases against loopback. No test writes to the live logistics service.

- Default suite: 43 passed; 51 API cases skipped and run separately.
- API-enabled suite: 51 passed (47 rider/logistics cases plus 4 existing API request tests).
- Focused analysis of changed rider models/screens/services and new tests: no issues.
- Broader rider analysis: 18 existing diagnostics in unchanged profile/navigation files (1 warning, 17 informational), no errors. The router also has existing lint diagnostics; no new compile errors were reported.
- `flutter devices`: Windows, Chrome, Edge only. Android/iOS camera, GPS, background lifecycle and live server integration remain untested.

## Using the changes

Rebuild/reinstall the mobile app with `--dart-define=API_ENABLED=true` and the correct backend URL. API access defaults to false in this repository. Source edits do not update an already installed APK.

Final device acceptance requires a test rider, seller pickup batch, logistics account and parcels on the same staging backend: accept/start, test a wrong code, collect valid parcels, mark an unavailable parcel, finish, then receive at the hub and compare all statuses. Also exercise camera permission denial/manual entry, GPS denial, transfer release/start, delivery proof and reconnect behavior.
