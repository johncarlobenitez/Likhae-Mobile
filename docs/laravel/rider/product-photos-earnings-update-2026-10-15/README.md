# Rider product photos and earnings update

Prepared against the Laravel source in:
`C:\Users\Administrator\Downloads\Likhae-working\Likhae-working`

## Deploy

1. Back up the server's `app/Http/Controllers/Api/RiderApiController.php`.
2. Copy this package's `app/Http/Controllers/Api/RiderApiController.php` to that same path in the deployed Laravel project.
3. From the Laravel project directory, run `php artisan optimize:clear`.
4. Ensure `public/storage` points to `storage/app/public`. If the link is missing, run `php artisan storage:link`. Product files must already exist on the server.
5. Restart the updated Flutter app and refresh the rider screens.

No new migrations or environment changes are required by this update. The deployed project must have the existing pickup batch, product variant, and rider earnings schema from the provided source.

## Changes

- Pickup batches and their parcels return the actual ordered variant photo, with the product's primary photo as a fallback. Batches use the first available product photo.
- Delivery assignments, history, and recent dashboard parcels use the same image selection. Relative public storage URLs resolve against the app's configured web origin.
- Dashboard and earnings responses include the authenticated rider's name.
- Earnings return the authenticated rider's recorded amounts, total earned, paid total, pending payout total, and count of shares awaiting allocation. Totals cover every page and exclude void/cancelled/rejected/failed records.
- Existing earnings remain visible alongside pool records; allocated pool shares replace legacy records for the same assignment to avoid counting both. A null share stays unallocated, rather than becoming a zero-value earning.

The endpoint displays existing earnings; it does not create payout rates or allocate shared pool balances. Product images require uploaded product files. The live server receives these changes only after this file is deployed.

## Validation

PHP syntax checked locally. Live API/device behavior and database integration have not been tested.
