LIKHAE Rider Workflow API patch

The rider app receives API endpoint not found (404) when loading Delivery trips,
Return parcels, and Vehicle & document review. This patch adds the missing
authenticated API routes and response handlers for those screens. It also
registers the existing profile update submission action.

Install at the Laravel project root
1. Copy app/Http/Controllers/Api/RiderWorkflowsApiController.php into the
   matching app directory.
2. Copy routes/rider_mobile_workflows.php into the routes directory.
3. In routes/mobile_parity.php, inside the existing api.v1.rider route group,
   add: require __DIR__.'/rider_mobile_workflows.php';
   Remove the existing profile/updates, returns, and trips route definitions
   from that group first, including their related action routes. This avoids
   duplicate route names. Keep the routes inside the rider group.
4. Run php artisan route:clear.

The list routes retain rider role, active rider, API token, policy acceptance,
and local-delivery operational checks. No database migration is included.

Verify after installation
- php artisan route:list --path=api/v1/rider/trips
- php artisan route:list --path=api/v1/rider/returns
- php artisan route:list --path=api/v1/rider/profile/updates
- Unauthenticated requests should return 401 instead of the missing-route 404.
