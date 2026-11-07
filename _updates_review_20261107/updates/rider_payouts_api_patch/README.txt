LIKHAE Rider Payouts API patch

The rider mobile app requests GET /api/v1/rider/payouts. The current deployed
Laravel API returns 404 because this route is missing there. This patch adds the
read endpoint used to load the rider's payout destination, eligible earnings,
and payout receipts.

Install at the Laravel project root
1. Copy app/Http/Controllers/Api/RiderPayoutsApiController.php into the matching
   Laravel app directory.
2. Copy routes/rider_payouts.php into the Laravel routes directory.
3. In routes/mobile_parity.php, inside the existing rider route group and its
   rider.operational:LOCAL_BARANGAY subgroup, add:

       require __DIR__.'/rider_payouts.php';

   Place it where the old Route::get('payouts', ...) was, and remove that old
   route line if it exists. Do not include both route definitions.
4. Run php artisan route:clear.

The route inherits the existing API bearer-token, policy, rider-role, active
rider, and local-delivery operational-type middleware. The endpoint returns
only the authenticated rider's payout data and marks the response private.
No migration is included; this uses the existing finance services and schema.

Verify after installation
- php artisan route:list --path=api/v1/rider/payouts should show the new route.
- An unauthenticated GET to /api/v1/rider/payouts should return 401, rather than
  the API endpoint not found 404.
